#!/usr/bin/env python3
"""Bounded, opt-in provisioning helpers for placerte/mathieu#10.

No VM creation, account authorization, bootstrap execution or host mutation.
"""
import argparse
import base64
import binascii
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import shlex
import subprocess
import sys
import time


class ProvisionError(Exception):
    pass


def positive(value):
    try:
        number = float(value)
    except ValueError:
        raise argparse.ArgumentTypeError('expected a positive finite number') from None
    if not 0 < number < float('inf'):
        raise argparse.ArgumentTypeError('expected a positive finite number')
    return number


def positive_int(value):
    if not value.isdecimal() or int(value) < 1:
        raise argparse.ArgumentTypeError('expected a positive integer')
    return int(value)


def run(command, timeout):
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=timeout,
                                env=dict(os.environ, LC_ALL='C'))
    except subprocess.TimeoutExpired:
        raise ProvisionError('external command timed out') from None
    except OSError:
        raise ProvisionError('external command unavailable') from None
    if result.returncode:
        # Never relay external stdout/stderr: it may contain credentials.
        raise ProvisionError('external command failed')
    return result.stdout


def virsh(*args, timeout=10):
    return run(['virsh', '-c', 'qemu:///system', *args], timeout)


def field(text, name):
    matches = re.findall(r'^' + re.escape(name) + r':\s*(.*?)\s*$', text, re.M)
    if len(matches) != 1:
        raise ProvisionError('missing or ambiguous host information')
    return matches[0]


def preflight(args):
    started = time.monotonic()
    tools = ('virsh', 'qemu-img', 'virt-install', 'cloud-localds', 'sha512sum', 'python3')
    missing = [tool for tool in tools if not shutil.which(tool)]
    if missing:
        raise ProvisionError('missing tools: ' + ', '.join(missing))
    available = int(field(Path('/proc/meminfo').read_text(), 'MemAvailable').split()[0]) // 1024
    if available < args.memory_mib + args.reserve_mib or (os.cpu_count() or 0) < args.vcpus:
        raise ProvisionError('insufficient available host memory or logical CPUs')
    if args.name in virsh('list', '--all', '--name', timeout=args.command_timeout).splitlines():
        raise ProvisionError('domain name collision')
    volumes = virsh('vol-list', args.pool, '--details', timeout=args.command_timeout)
    rows = volumes.strip().splitlines()
    if (len(rows) < 2 or rows[0].split() != ['Name', 'Path', 'Type', 'Capacity', 'Allocation']
            or not re.fullmatch(r'\s*-+\s*', rows[1])
            or any(len(row.split()) < 5 for row in rows[2:] if row.strip())):
        raise ProvisionError('malformed volume inventory')
    names = {line.split()[0] for line in rows[2:] if line.strip()}
    if names.intersection({args.name + '.qcow2', args.name + '-seed.iso'}):
        raise ProvisionError('volume name collision')
    pool = virsh('pool-info', args.pool, '--bytes', timeout=args.command_timeout)
    if field(pool, 'State') != 'running' or int(field(pool, 'Available')) < args.disk_gib * 2**30:
        raise ProvisionError('inactive pool or insufficient pool capacity')
    network = virsh('net-info', args.network, timeout=args.command_timeout)
    if field(network, 'Active') != 'yes':
        raise ProvisionError('network is inactive')
    image = Path(args.image)
    entries = []
    for line in Path(args.checksums).read_text().splitlines():
        match = re.fullmatch(r'([0-9a-fA-F]{128}) [ *](.+)', line)
        if match and match[2] == image.name:
            entries.append(match[1].lower())
    if len(entries) != 1:
        raise ProvisionError('image needs exactly one SHA512 entry in operator-authenticated manifest')
    digest = hashlib.sha512()
    with image.open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(block)
    if digest.hexdigest() != entries[0]:
        raise ProvisionError('cached image checksum mismatch; do not reuse')
    info = json.loads(run(['qemu-img', 'info', '--output=json', str(image.resolve())], args.command_timeout))
    if (info.get('format') != 'qcow2' or 'backing-filename' in info
            or not isinstance(info.get('virtual-size'), int)
            or not 0 < info['virtual-size'] <= args.disk_gib * 2**30):
        raise ProvisionError('image must be standalone qcow2 fitting requested disk')
    return {'phase': 'preflight', 'status': 'ready', 'cache': 'verified-reuse',
            'memory_available_mib': available, 'logical_cpus': os.cpu_count(),
            'elapsed_seconds': round(time.monotonic() - started, 3)}


def identifier(value):
    if not re.fullmatch(r'[a-z][a-z0-9-]{0,62}', value):
        raise argparse.ArgumentTypeError('expected a lowercase identifier (1-63 characters)')
    return value


def runtime_user(value):
    if not re.fullmatch(r'[a-z_][a-z0-9_-]{0,31}', value) or value == 'root':
        raise argparse.ArgumentTypeError('expected a non-root Unix username')
    return value


def cloud_init(name, user):
    home = f'/home/{user}'
    return f'''#cloud-config
hostname: {json.dumps(name)}
manage_etc_hosts: true
disable_root: true
ssh_pwauth: false
users:
  - name: {json.dumps(user)}
    groups: [sudo]
    shell: /usr/bin/zsh
    lock_passwd: true
    sudo: null
packages:
  - zsh
  - qemu-guest-agent
  - git
  - sudo
runcmd:
  - [install, -d, -m, '0700', {home}/.hermes/cache/scratch]
  - [sh, -c, 'chown {user}:{user} {home}/.hermes {home}/.hermes/cache {home}/.hermes/cache/scratch']
  - [sh, -c, 'chmod 0700 {home}/.hermes {home}/.hermes/cache {home}/.hermes/cache/scratch']
  - [systemctl, start, qemu-guest-agent.service]
'''


BOOTSTRAP_COMMIT = 'ce58d9e8f6559b4dddf9120925320319b2d778cc'
RESUME_COMPONENTS = {'hermes': '56', 'codex': '55'}


def bootstrap_plan(args):
    home = f'/home/{args.user}'
    command = ['bash', 'bootstrap.sh']
    if args.resume:
        command += ['--profile', 'cherry-pick', '--components', RESUME_COMPONENTS[args.resume],
                    '--without-chezmoi', '--yes']
    else:
        command += ['--profile', 'headless', '--without-chezmoi', '--with-codex', '--with-hermes', '--yes']
    script = (f'umask 077; pin=$(git rev-parse HEAD) || exit 1; test "$pin" = {BOOTSTRAP_COMMIT} '
              '|| exit 1; dirty=$(git status --porcelain) || exit 1; test -z "$dirty" || exit 1; '
              f'exec {shlex.join(command)} >>{home}/bootstrap-install.log 2>&1')
    launch = ['systemd-run', f'--unit=bootstrap-{args.name}',
              f'--property=User={args.user}', f'--property=WorkingDirectory={home}/bootstrap',
              '--property=UMask=0077', '--property=Type=exec', '--property=RemainAfterExit=yes',
              '--property=RuntimeMaxSec=1800', '--property=StandardOutput=null',
              '--property=StandardError=null', f'--setenv=HOME={home}', '--setenv=SHELL=/usr/bin/zsh',
              f'--setenv=TMPDIR={home}/.hermes/cache/scratch', '--setenv=DEBIAN_FRONTEND=noninteractive',
              f'--setenv=PATH={home}/.local/bin:/usr/local/bin:/usr/bin:/bin', '/bin/bash', '-c', script]
    return {'phase': 'bootstrap-plan', 'status': 'not-executed', 'commit': BOOTSTRAP_COMMIT,
            'bootstrap_argv': command, 'launch_argv': launch,
            'service': f'bootstrap-{args.name}.service'}


def domain_uuid(value):
    if not re.fullmatch(r'[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}', value):
        raise argparse.ArgumentTypeError('expected exact domain UUID, not a mutable domain name')
    return value


def service_name(value):
    if not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9_.-]{0,120}\.service', value):
        raise argparse.ArgumentTypeError('expected a simple system service unit name')
    return value


def qga(domain, request, deadline):
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise ProvisionError('phase deadline exceeded')
    response = json.loads(virsh('qemu-agent-command', domain, json.dumps(request),
                                timeout=min(5, remaining)))
    if not isinstance(response, dict) or 'error' in response or not isinstance(response.get('return'), dict):
        raise ValueError('malformed guest-agent response')
    return response['return']


def guest_status(response):
    if type(response.get('exited')) is not bool:
        raise ValueError('missing guest execution status')
    if not response['exited']:
        return None
    if type(response.get('exitcode')) is not int:
        raise ValueError('missing guest exit code')
    if response.get('out-truncated', False) is not False or response.get('err-truncated', False) is not False:
        raise ProvisionError('truncated guest output; inspect privately before retry')
    try:
        output = base64.b64decode(response.get('out-data', ''), validate=True).decode('utf-8')
    except (binascii.Error, UnicodeError):
        raise ValueError('invalid guest output encoding') from None
    return response['exitcode'], output


def wait_ready(args):
    started = time.monotonic()
    deadline = started + args.timeout
    pid = None
    while time.monotonic() < deadline:
        try:
            if args.phase == 'agent':
                response = qga(args.domain, {'execute': 'guest-ping'}, deadline)
                if response != {}:
                    raise ValueError('malformed ping response')
                break
            if pid is None:
                path, command = ('/usr/bin/cloud-init', ['status', '--format', 'json'])
                if args.phase == 'service':
                    path, command = ('/usr/bin/systemctl', ['show', args.service,
                        '--property=LoadState,ActiveState,SubState,Result,ExecMainStatus'])
                try:
                    response = qga(args.domain, {'execute': 'guest-exec', 'arguments': {
                        'path': path, 'arg': command, 'capture-output': True}}, deadline)
                except ProvisionError:
                    raise ProvisionError('guest execution submission uncertain; inspect before retry') from None
                pid = response.get('pid')
                if type(pid) is not int or pid < 1:
                    raise ValueError('missing guest process ID')
            response = qga(args.domain, {'execute': 'guest-exec-status', 'arguments': {'pid': pid}}, deadline)
            status = guest_status(response)
            if status is not None:
                pid = None
                code, output = status
                if code:
                    raise ValueError('guest check failed (cloud-init code 2 is degraded, not success)')
                if args.phase == 'cloud-init':
                    cloud = json.loads(output)
                    if cloud.get('errors') or cloud.get('status') not in ('done', 'running', 'not started'):
                        raise ValueError('cloud-init error or unknown state')
                    if cloud['status'] == 'done':
                        break
                else:
                    lines = output.strip().splitlines()
                    properties = dict(line.split('=', 1) for line in lines)
                    if len(properties) != len(lines) or set(properties) != {
                            'LoadState', 'ActiveState', 'SubState', 'Result', 'ExecMainStatus'}:
                        raise ValueError('malformed service properties')
                    if properties == {'LoadState': 'loaded', 'ActiveState': 'active', 'SubState': 'exited',
                                      'Result': 'success', 'ExecMainStatus': '0'}:
                        break
                    if (properties['LoadState'] != 'loaded' or properties['Result'] != 'success'
                            or properties['ActiveState'] not in ('active', 'activating')):
                        raise ValueError('service failed or is not running')
        except ProvisionError as error:
            # Only transport failures are retryable; never replay a pending guest-exec.
            if str(error) not in ('external command failed', 'external command timed out'):
                raise
        time.sleep(min(args.interval, max(0, deadline - time.monotonic())))
    else:
        raise ProvisionError('phase deadline exceeded')
    return {'phase': args.phase, 'status': 'ready', 'elapsed_seconds': round(time.monotonic() - started, 3)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    cloud = commands.add_parser('cloud-init', help='render fresh secret-free user-data to stdout')
    cloud.add_argument('--name', type=identifier, required=True)
    cloud.add_argument('--user', type=runtime_user, required=True)
    host = commands.add_parser('preflight', help='read-only checks on the local libvirt host')
    host.add_argument('--name', type=identifier, required=True)
    host.add_argument('--pool', type=identifier, default='default')
    host.add_argument('--network', type=identifier, default='default')
    host.add_argument('--image', required=True)
    host.add_argument('--checksums', required=True, help='operator-authenticated official SHA512SUMS')
    host.add_argument('--memory-mib', type=positive_int, default=4096)
    host.add_argument('--reserve-mib', type=positive_int, default=1024)
    host.add_argument('--disk-gib', type=positive_int, default=40)
    host.add_argument('--vcpus', type=positive_int, default=2)
    host.add_argument('--command-timeout', type=positive, default=10)
    plan = commands.add_parser('bootstrap-plan', help='render only; never launches bootstrap')
    plan.add_argument('--name', type=identifier, required=True)
    plan.add_argument('--user', type=runtime_user, required=True)
    plan.add_argument('--resume', choices=RESUME_COMPONENTS)
    readiness = commands.add_parser('wait', help='bounded read-only guest readiness checks via QGA')
    readiness.add_argument('--domain', type=domain_uuid, required=True)
    readiness.add_argument('--phase', choices=('agent', 'cloud-init', 'service'), required=True)
    readiness.add_argument('--service', type=service_name)
    readiness.add_argument('--timeout', type=positive, default=300)
    readiness.add_argument('--interval', type=positive, default=2)
    args = parser.parse_args()
    if args.command == 'wait' and args.phase == 'service' and not args.service:
        parser.error('--phase service requires --service')
    started = time.monotonic()
    try:
        if args.command == 'cloud-init':
            print(cloud_init(args.name, args.user), end='')
        elif args.command == 'bootstrap-plan':
            print(json.dumps(bootstrap_plan(args), sort_keys=True))
        elif args.command == 'wait':
            print(json.dumps(wait_ready(args), sort_keys=True))
        elif args.command == 'preflight':
            print(json.dumps(preflight(args), sort_keys=True))
    except (ProvisionError, OSError, ValueError, TypeError, KeyError, AttributeError) as error:
        message = str(error) if isinstance(error, ProvisionError) else 'unreadable or malformed input'
        phase = args.phase if args.command == 'wait' else args.command
        print(json.dumps({'phase': phase, 'status': 'failed', 'reason': message,
                          'elapsed_seconds': round(time.monotonic() - started, 3)}))
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
