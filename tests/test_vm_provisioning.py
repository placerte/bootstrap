"""Local boundary fixtures, never a live VM or installer."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / 'provisioning' / 'vm.py'


def cli(*args, env=None):
    return subprocess.run([sys.executable, str(TOOL), *args], text=True,
                          capture_output=True, env=env)


class CloudInitTests(unittest.TestCase):
    def test_fresh_cloud_init_has_no_seed_identity_and_explicit_parent_modes(self):
        result = cli('cloud-init', '--name', 'new-agent', '--user', 'runtime')
        self.assertEqual(result.returncode, 0, result.stderr)
        data = result.stdout
        for value in ('#cloud-config', 'sudo: null', 'shell: /usr/bin/zsh',
                      '  - zsh', 'lock_passwd: true', 'ssh_pwauth: false',
                      'chown runtime:runtime /home/runtime/.hermes /home/runtime/.hermes/cache /home/runtime/.hermes/cache/scratch',
                      'chmod 0700 /home/runtime/.hermes', 'qemu-guest-agent'):
            self.assertIn(value, data)
        for value in ('NOPASSWD', 'ssh_authorized_keys', 'auth.json', 'justine', 'sudo: false'):
            self.assertNotIn(value, data)
        invalid = cli('cloud-init', '--name', 'bad;command', '--user', 'runtime')
        self.assertNotEqual(invalid.returncode, 0)
        self.assertNotIn('#cloud-config', invalid.stdout)


class BootstrapPlanTests(unittest.TestCase):
    def test_rendered_launcher_enforces_pin_and_clean_checkout_before_execution(self):
        plan = json.loads(cli('bootstrap-plan', '--name', 'new-agent', '--user', 'runtime').stdout)
        # Exercise the actual shell guards; replace only installer execution with a marker.
        script = plan['launch_argv'][-1].split('exec ', 1)[0] + 'printf BOOTSTRAP_STARTED'
        with tempfile.TemporaryDirectory(dir=os.environ.get('TMPDIR')) as directory:
            base = Path(directory)
            git = base / 'git'
            git.write_text('#!/bin/sh\nif [ "$1" = rev-parse ]; then printf "%s\\n" "$PIN"; exit 0; fi\nexit 1\n')
            git.chmod(0o755)
            # A correct pin but failing status inspection MUST NOT run bootstrap.
            env = dict(os.environ, PATH=f'{base}:' + os.environ['PATH'], PIN=plan['commit'])
            result = subprocess.run(['/bin/bash', '-c', script], cwd=ROOT, env=env,
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn('bootstrap-install.log', result.stderr)

    def test_pinned_plan_and_component_only_resume_are_unattended_not_executed(self):
        pin = 'ce58d9e8f6559b4dddf9120925320319b2d778cc'
        result = cli('bootstrap-plan', '--name', 'new-agent', '--user', 'runtime')
        self.assertEqual(result.returncode, 0, result.stderr)
        plan = json.loads(result.stdout)
        self.assertEqual(plan['commit'], pin)
        self.assertEqual(plan['bootstrap_argv'], ['bash', 'bootstrap.sh', '--profile', 'headless',
                         '--without-chezmoi', '--with-codex', '--with-hermes', '--yes'])
        launch = ' '.join(plan['launch_argv'])
        for value in (pin, 'rev-parse HEAD', 'status --porcelain', 'UMask=0077',
                      'HOME=/home/runtime', 'SHELL=/usr/bin/zsh', 'TMPDIR=',
                      'DEBIAN_FRONTEND=noninteractive', 'RuntimeMaxSec=1800', 'User=runtime'):
            self.assertIn(value, launch)
        for component, prefix in (('hermes', '56'), ('codex', '55')):
            resume = cli('bootstrap-plan', '--name', 'new-agent', '--user', 'runtime', '--resume', component)
            self.assertEqual(resume.returncode, 0, resume.stderr)
            command = json.loads(resume.stdout)['bootstrap_argv']
            self.assertEqual(command, ['bash', 'bootstrap.sh', '--profile', 'cherry-pick',
                                      '--components', prefix, '--without-chezmoi', '--yes'])
            dry = subprocess.run([*command, '--dry-run', '--platform', 'debian'], cwd=ROOT,
                                 capture_output=True, text=True)
            self.assertEqual(dry.returncode, 0, dry.stderr)
            self.assertIn(prefix + '-' + component + '.sh', dry.stdout)
            self.assertNotIn('10-base-packages.sh', dry.stdout)
        self.assertNotIn('--ai-login', launch)
        self.assertNotIn('--tailscale-up', launch)


class HostFixture(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=os.environ.get('TMPDIR'))
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.bin = self.base / 'bin'
        self.bin.mkdir()
        self.log = self.base / 'calls.jsonl'
        fixture = '''#!/usr/bin/python3
import json, os, sys, time
from pathlib import Path
args = sys.argv[1:]
with open(os.environ['CALL_LOG'], 'a') as f:
    f.write(json.dumps([Path(sys.argv[0]).name, *args]) + '\\n')
scenario = os.environ.get('SCENARIO', '')
if scenario == 'hang':
    time.sleep(2)
if Path(sys.argv[0]).name == 'qemu-img':
    print(json.dumps({'format': 'qcow2', 'virtual-size': 1024,
                      **({'backing-filename': '/peer/private.qcow2'} if scenario == 'backing' else {})}))
    sys.exit(0)
args = args[2:]  # -c qemu:///system
if args == ['list', '--all', '--name']:
    print('new-agent' if scenario == 'domain-collision' else 'existing-agent')
elif args == ['vol-list', 'default', '--details']:
    if scenario == 'malformed-volumes':
        print('unexpected response')
        sys.exit(0)
    print(' Name Path Type Capacity Allocation\\n------------------------------------')
    print('new-agent.qcow2 /pool/new-agent.qcow2 file 1 1' if scenario == 'volume-collision' else 'existing.qcow2 /pool/existing.qcow2 file 1 1')
elif args == ['pool-info', 'default', '--bytes']:
    print('State: running\\nAvailable: ' + ('1' if scenario == 'disk-full' else '1099511627776'))
elif args == ['net-info', 'default']:
    print('Active: no' if scenario == 'network-down' else 'Active: yes')
elif args and args[0] == 'qemu-agent-command':
    import base64
    request = json.loads(args[2])
    execute = request['execute']
    if scenario == 'agent-unavailable':
        sys.exit(1)
    if scenario == 'malformed-qga':
        print('{not JSON')
    elif execute == 'guest-ping':
        print('{"return": {}}')
    elif execute == 'guest-exec':
        if scenario == 'submission-uncertain':
            sys.exit(1)
        Path(os.environ['CALL_LOG'] + '.request').write_text(json.dumps(request))
        print('{"return": {"pid": 42}}')
    elif execute == 'guest-exec-status':
        saved = json.loads(Path(os.environ['CALL_LOG'] + '.request').read_text())
        path = saved['arguments']['path']
        if path == '/usr/bin/cloud-init':
            text = json.dumps({'status': 'running' if scenario == 'cloud-running' else 'done', 'errors': []})
        else:
            text = 'LoadState=loaded\\nActiveState=active\\nSubState=exited\\nResult=success\\nExecMainStatus=0\\n'
            if scenario == 'service-failed':
                text = 'LoadState=loaded\\nActiveState=failed\\nSubState=failed\\nResult=exit-code\\nExecMainStatus=1\\n'
        response = {'exited': scenario != 'exec-pending', 'exitcode': 2 if scenario == 'cloud-warning' else 0,
                    'out-data': base64.b64encode(text.encode()).decode()}
        if scenario == 'truncated':
            response['out-truncated'] = True
        if scenario == 'bad-base64':
            response['out-data'] = '!!!'
        if scenario == 'missing-exited':
            del response['exited']
        if scenario == 'boolean-exitcode':
            response['exitcode'] = False
        if scenario == 'qga-error-with-return':
            print(json.dumps({'return': response, 'error': {'class': 'GenericError'}}))
            sys.exit(0)
        print(json.dumps({'return': response}))
    else:
        sys.exit(9)
else:
    sys.exit(9)
'''
        for name in ('virsh', 'qemu-img', 'virt-install', 'cloud-localds', 'sha512sum'):
            path = self.bin / name
            path.write_text(fixture)
            path.chmod(0o755)
        self.env = dict(os.environ, PATH=f'{self.bin}:' + os.environ['PATH'], CALL_LOG=str(self.log))
        self.image = self.base / 'debian.qcow2'
        self.image.write_bytes(b'fixture image, not a bootable guest')
        import hashlib
        self.sums = self.base / 'SHA512SUMS.operator-verified'
        self.sums.write_text(hashlib.sha512(self.image.read_bytes()).hexdigest() + '  debian.qcow2\n')

    def preflight(self, *extra):
        return cli('preflight', '--name', 'new-agent', '--image', str(self.image),
                   '--checksums', str(self.sums), '--memory-mib', '1', '--reserve-mib', '1',
                   '--disk-gib', '1', *extra, env=self.env)

    def wait(self, phase, *extra):
        return cli('wait', '--domain', '11111111-2222-4333-8444-555555555555',
                   '--phase', phase, '--timeout', '0.5', '--interval', '0.01',
                   '--service', 'bootstrap-new-agent.service', *extra, env=self.env)

    def test_bounded_qga_readiness_reports_phase_results_without_guest_output(self):
        for phase in ('agent', 'cloud-init', 'service'):
            with self.subTest(phase=phase):
                result = self.wait(phase)
                self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
                report = json.loads(result.stdout)
                self.assertEqual(report['status'], 'ready')
                self.assertEqual(report['phase'], phase)
                self.assertGreaterEqual(report['elapsed_seconds'], 0)
                self.assertNotIn('out-data', result.stdout)
        self.assertTrue(self.log.exists(), 'readiness must call the external virsh boundary')
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        requests = [json.loads(call[5]) for call in calls]
        paths = [r['arguments']['path'] for r in requests if r['execute'] == 'guest-exec']
        self.assertEqual(paths, ['/usr/bin/cloud-init', '/usr/bin/systemctl'])
        for scenario, phase in (('agent-unavailable', 'agent'), ('exec-pending', 'service'),
                                ('cloud-running', 'cloud-init'), ('cloud-warning', 'cloud-init'),
                                ('service-failed', 'service'), ('malformed-qga', 'agent'),
                                ('truncated', 'service'), ('bad-base64', 'service'),
                                ('missing-exited', 'service'), ('hang', 'agent')):
            with self.subTest(scenario=scenario):
                self.env['SCENARIO'] = scenario
                started = __import__('time').monotonic()
                result = self.wait(phase, '--timeout', '0.15')
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(json.loads(result.stdout)['status'], 'failed')
                self.assertLess(__import__('time').monotonic() - started, 1.5)
        self.env.pop('SCENARIO')
        for flag, value in (('--domain', 'arbitrary-domain'), ('--timeout', '0'),
                            ('--interval', '-1'), ('--service', 'unit;bad.service')):
            with self.subTest(flag=flag):
                self.assertNotEqual(self.wait('service', flag, value).returncode, 0)

    def test_ambiguous_guest_submission_is_not_replayed(self):
        self.env['SCENARIO'] = 'submission-uncertain'
        result = self.wait('service')
        self.assertNotEqual(result.returncode, 0)
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        self.assertEqual(len(calls), 1, 'unknown submission must require operator review, not replay')

    def test_guest_error_envelope_cannot_be_accepted_as_success(self):
        self.env['SCENARIO'] = 'qga-error-with-return'
        result = self.wait('service')
        self.assertNotEqual(result.returncode, 0)
        report = json.loads(result.stdout)
        self.assertEqual(report['phase'], 'service')
        self.assertEqual(report['status'], 'failed')
        self.env['SCENARIO'] = 'boolean-exitcode'
        self.assertNotEqual(self.wait('service').returncode, 0)

    def test_preflight_fails_closed_on_malformed_inventory_and_bad_inputs(self):
        self.env['SCENARIO'] = 'malformed-volumes'
        self.assertNotEqual(self.preflight().returncode, 0)
        self.env['SCENARIO'] = 'hang'
        result = self.preflight('--command-timeout', '0.05')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('timed out', result.stdout)
        self.env.pop('SCENARIO')
        for flag, value in (('--memory-mib', '0'), ('--disk-gib', '-1'),
                            ('--vcpus', '0'), ('--reserve-mib', '0'),
                            ('--command-timeout', 'nan'), ('--name', 'bad/name'),
                            ('--memory-mib', '999999999999')):
            with self.subTest(flag=flag, value=value):
                self.assertNotEqual(self.preflight(flag, value).returncode, 0)
        self.sums.write_text(self.sums.read_text() * 2)
        self.assertNotEqual(self.preflight().returncode, 0)
        (self.bin / 'cloud-localds').unlink()
        self.assertNotEqual(self.preflight().returncode, 0)

    def test_read_only_preflight_checks_capacity_collisions_and_verified_cache(self):
        result = self.preflight()
        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual(report['status'], 'ready')
        self.assertEqual(report['cache'], 'verified-reuse')
        self.assertGreaterEqual(report['elapsed_seconds'], 0)
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        self.assertIn(['virsh', '-c', 'qemu:///system', 'list', '--all', '--name'], calls)
        self.assertIn(['virsh', '-c', 'qemu:///system', 'vol-list', 'default', '--details'], calls)
        self.assertTrue(all(call[0] == 'qemu-img' or call[3] in ('list', 'vol-list', 'pool-info', 'net-info') for call in calls))
        for scenario in ('domain-collision', 'volume-collision', 'disk-full', 'network-down', 'backing'):
            with self.subTest(scenario=scenario):
                self.env['SCENARIO'] = scenario
                self.assertNotEqual(self.preflight().returncode, 0)
        self.env.pop('SCENARIO')
        self.image.write_bytes(b'corrupt cache')
        self.assertNotEqual(self.preflight().returncode, 0)


if __name__ == '__main__':
    unittest.main()
