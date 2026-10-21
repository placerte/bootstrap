# Bounded VM provisioning helpers

Source: **placerte/mathieu#10**, bounded quick wins from the Justine provisioning
post-mortem. This is separate support around the existing bootstrap, not the full
provisioner (#9), account lifecycle (#8), or measurement framework (#7).

`provisioning/vm.py` uses Python 3 stdlib only. It renders fresh cloud-init and a
pinned bootstrap launch plan, performs a **local read-only host preflight**, and
waits for known guest phases through libvirt/QEMU guest agent (QGA). It never
creates a VM, downloads an image, installs packages, runs bootstrap, grants sudo,
changes host/tailnet policy, or executes account login. Run preflight/wait on the
libvirt host under its authorized ordinary account, not inside a peer guest.
QGA guest-exec is root-capable: this helper permits only fixed read-only status
commands, not an arbitrary guest shell or authentication command.

## 1. Read-only host preflight and verified cache reuse

Discover the exact official Debian genericcloud image/cache location first; do
not guess or copy a peer VM disk. Obtain the matching `SHA512SUMS` from the
**official HTTPS Debian cloud image directory** through an operator-authenticated
retrieval, retaining its source URL/date separately. Pin a dated image release
when possible; `latest` can move. A checksum generated from the local image, or
an arbitrary adjacent digest, is **not provenance**. The helper trusts the
operator-supplied manifest; it does not authenticate the manifest itself, fetch
it, or claim signature verification. Do not refresh a missing/mismatched cache
automatically. Refresh the image and matching manifest together after review.

On the host, with actual existing paths:

```bash
python3 provisioning/vm.py preflight --name new-agent \
  --image /operator/selected/debian-13-genericcloud-amd64.qcow2 \
  --checksums /operator/authenticated/SHA512SUMS \
  --pool default --network default \
  --vcpus 2 --memory-mib 4096 --reserve-mib 1024 --disk-gib 40
```

This checks required tools (`virsh`, `qemu-img`, `virt-install`, `cloud-localds`,
`sha512sum`, `python3`), logical CPU count, Linux `MemAvailable` plus the requested
memory reserve, active network/pool, pool free bytes, all defined domain names,
and selected-pool volume collisions for **`NAME.qcow2` and `NAME-seed.iso`**. Use
these exact names for subsequent separately approved provisioning. A cache is
reusable only with one matching SHA512 manifest entry and standalone qcow2
metadata (no backing image, virtual size fitting the requested disk).

Commands have `--command-timeout` (default 10 seconds per external command).
Failures return nonzero and concise JSON; raw command output is not relayed.
The checksum streams the local file and is not subject to the external-command
timeout. No reservation/locking is made: this is a point-in-time capacity and
name check, not protection from a later race. It does not promise dedicated
physical CPU capacity, check UEFI firmware, account for stopped-VM reservations,
or prove a valid image boots. Recheck collisions immediately before any future
create; do not overwrite an existing domain/volume or widen host sudo. Additional
seed/log disk headroom and policy/firmware checks remain the operator's job.

## 2. Render fresh cloud-init (no inherited identity)

```bash
umask 077
python3 provisioning/vm.py cloud-init --name new-agent --user runtime > user-data
```

The renderer installs zsh and QEMU guest agent, sets the user's zsh shell and
locked password, disables SSH password auth/root login, and uses **`sudo: null`**
(not deprecated `false`). It explicitly chowns `.hermes`, `.hermes/cache`, and
`.hermes/cache/scratch`, and sets all three to **0700**. `install -d -o USER`
alone would not fix ownership of newly created parents. User-data contains no
auth keys, peer files, private tokens, temporary unrestricted sudo, login command,
or copied identity. It is generated afresh, not adapted from an as-built seed.

This command only renders YAML; it does not run cloud-init. Review/schema-check
it on the target distribution before an independently authorized build. Use a
fresh official image, unique domain UUID/MAC, machine-id and SSH host keys; never
clone an agent's disk. Seed/metadata creation and libvirt volume creation/upload
remain out of scope. Never recursively transfer `.hermes`, `.codex`, Tailscale
state, `.env`, GPG/pass stores, session databases, mailbox data or peer seeds.

## 3. Bounded readiness, not repeated model polling

After separately authorized provisioning, use the **exact domain UUID**, not its
mutable name. Each invocation prints one JSON phase result with monotonic
`elapsed_seconds`; append only these secret-free summaries to a private timing
file if desired.

```bash
python3 provisioning/vm.py wait --domain "$DOMAIN_UUID" --phase agent --timeout 300
python3 provisioning/vm.py wait --domain "$DOMAIN_UUID" --phase cloud-init --timeout 600
# Only after the human has deliberately launched the reviewed plan below:
python3 provisioning/vm.py wait --domain "$DOMAIN_UUID" --phase service \
  --service bootstrap-new-agent.service --timeout 1800
```

The phase deadline covers external calls and sleeps (`--interval` defaults to 2
seconds, each RPC capped at 5 seconds or remaining time). Agent availability can
lag apt/cloud-init; wait for agent, then cloud-init, then bootstrap. The helper
polls only `guest-ping`, `cloud-init status --format json`, and `systemctl show`.
It never invokes an installer/auth command. A pending guest-exec PID is polled
without replay. An uncertain guest-exec submission fails for private operator
review instead of resubmitting it. An expired deadline stops the local waiter;
it does not kill a guest status process or cancel a separately launched service.

Cloud-init needs `status=done` and exit 0. Exit 2 (degraded/recoverable warnings)
is **not accepted as clean success**; inspect warnings privately, fix or explicitly
record the exception. Malformed JSON, missing status/exit fields, invalid base64,
and truncated QGA output fail closed. The service check is specifically for a
completed **RemainAfterExit** bootstrap unit: loaded, active/exited, Result=success,
ExecMainStatus=0. Merely running, a missing/failed unit, or root-route HTTP 404 is
not proof of installation success. No guest stdout/stderr/auth output is printed.

## 4. Pinned unattended bootstrap and narrow resume (plan only)

Stage the **complete clean repository** at `/home/runtime/bootstrap`, checked out
at `ce58d9e8f6559b4dddf9120925320319b2d778cc`; fetching just `bootstrap.sh`
is insufficient because remote fallback resources track `main`. The launch plan
verifies exact HEAD and a clean worktree before running anything. The revision
is the reviewed Justine baseline, not a claim that dependency installers are
pinned. Record actual installed versions; upstream installers can change.

```bash
python3 provisioning/vm.py bootstrap-plan --name new-agent --user runtime
python3 provisioning/vm.py bootstrap-plan --name new-agent --user runtime --resume hermes
python3 provisioning/vm.py bootstrap-plan --name new-agent --user runtime --resume codex
```

These commands **only print JSON**, including `bootstrap_argv` and `launch_argv`.
They do not execute the plan. The exact normal command is:

```bash
bash bootstrap.sh --profile headless --without-chezmoi --with-codex --with-hermes --yes
```

The rendered transient system service runs as the runtime user, with explicit
HOME/SHELL/TMPDIR/PATH/DEBIAN_FRONTEND, UMask=0077, a 30-minute RuntimeMaxSec, and
RemainAfterExit=yes for reliable completion checks. Installer output appends to
`/home/runtime/bootstrap-install.log` under the runtime user's restrictive umask;
review existing logs' ownership/mode and reject symlinks before authorized launch.
Nothing logs into accounts. Keep logs private/uncommitted. A root-authorized
operator must explicitly review/launch the argv inside the intended guest, and
separately decide any temporary guest sudo needed by bootstrap. The template and
helper **never grant it**. Do not grant host sudo. Remove any separately approved
temporary guest grant, validate sudoers, and verify `sudo -n true` fails before
handoff. Without such an approved provisioning privilege path, bootstrap will
fail; that is deliberate, not an authorization bypass to automate.

Diagnose the failed component first. Hermes resume is only:

```bash
bash bootstrap.sh --profile cherry-pick --components 56 --without-chezmoi --yes
```

Codex uses `--components 55`. Existing pre/postflight checks still run, not the
other install components. Preview with `--dry-run` first. After reviewing the
original result, explicitly stop/reset the old transient unit before reusing its
name; don't hide failed-unit evidence or restart a still-running install. Other
component recovery uses the existing bootstrap cherry-pick interface, not a new
resume/state framework.

## 5. Independent account checkpoints (human-owned, never automated here)

Start each as **PENDING / NOT VERIFIED**. Software installation is not account
approval. Mark skipped/disconnected integrations as such; don't repeatedly ask
for consent or claim them complete.

| Checkpoint | Required independent read-back after human consent |
| --- | --- |
| Tailscale | This new node's actual backend identity and approved SSH paths |
| Standalone Codex | This runtime user's own auth state and bounded live no-tool request |
| Hermes model provider | Separate auth state and bounded live request; Codex approval alone is insufficient |
| Google/mail/calendar (optional) | Separate client/consent, actual readonly scopes and live readonly access; otherwise disconnected |

No approval URLs/codes are generated, stored, or replayed by these helpers.
During separately authorized manual login, relay the **existing current** pending
approval URL/code through a private channel; don't regenerate a link while the
human approves it. Never commit approval links, tokens or login output. Verify
actual backend state rather than trusting only a reported click. Keep temporary
login output owner-only and remove it after success. Don't copy credentials from
peers or reuse authorizations to imply independent identities. Local sudo removal
does not isolate a node whose tailnet owner/default policy still reaches a
libvirt/wheel host account. Record this boundary and obtain human policy approval;
no ACL/tag/peer-access changes are included in this work.

## Acceptance / evidence checklist

Local regression acceptance (no throwaway VM needed):

- [ ] `bash tests/run.sh` passes, including stdlib subprocess fixtures at the
      virsh/QGA boundary; no package installs or remote commands.
- [ ] Render fresh cloud-init and inspect sudo:null, zsh, explicit parent owner and
      0700 modes; no seed identities/secrets or sudoers grant.
- [ ] Preflight reports verified cache reuse; corrupt/ambiguous manifest, backing
      image, capacity/name conflicts, missing tools and malformed inventories fail.
- [ ] Full pinned command and Hermes/Codex component-only dry-run plans match;
      failed Git inspection cannot bypass the revision/worktree guards.
- [ ] Agent/cloud-init/service fixtures cover success, deadlines, service failure,
      degraded cloud-init, malformed/truncated QGA, and uncertain exec submission.

On the **next independently authorized real build**, not as part of these tests:

- [ ] Capture secret-free preflight and each wait result plus UTC phase start/end;
      distinguish waiter latency from actual installer duration. Preserve service
      start/finish metadata and versions privately. These are not a token-cost
      benchmark and a late waiter doesn't measure the whole phase.
- [ ] Verify rendered cloud-init with target tooling and actual ownership/modes,
      unique identities, bootstrap service/log result, no failed units, independent
      account read-backs, sudo removal, and seed ejection/reboot persistence.
- [ ] Record skipped authorizations and untested client/peer paths explicitly;
      no credential files, user data, raw logs or approval links in the evidence.

The fixture image is deliberately not bootable. Passing this suite proves local
helper/control-flow contracts, not cloud-init execution, successful apt installs,
live QGA compatibility, real boot/readiness, account authorization, or end-to-end
VM provisioning. No new VM is required or created to validate this change.
