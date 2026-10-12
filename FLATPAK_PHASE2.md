# Flatpak Phase 2 source checkpoint — 2026-10-08

> **Historical engineering checkpoint.** This file preserves interim development
> observations, some of which predate the final first-boot fix. For current
> hardware-pilot results and release boundaries, see
> [Phase 2 runtime acceptance](docs/PHASE2_RUNTIME_ACCEPTANCE.md) and
> [Phase 2 release notes](RELEASE_NOTES_PHASE2.md).
> Later numbered development notes are not evidence that Phase 3 or subsequent
> deployment phases were authorized or completed.

Stage A: **PASS**. Phase 2 source checks: **PASS** (retained from the existing
checkpoint). Phase 2 runtime acceptance: **BLOCKED**. The exact implementation
has been committed locally, restored successfully from a self-contained Git
bundle, and saved to persistent storage with a byte-identical readback. Debian 13
runtime validation could not proceed in this workspace. Later phases,
enterprise changes, publishing, and merging remain unauthorized.

## Git evidence

| Item | Observed value |
| --- | --- |
| Origin fetch/push URL | `https://github.com/Q-D-4/EDBP.git` |
| Fetched `origin/main` and base commit | `de22642905d8073196471b580464c7fdfa5a21a6` |
| Base checkout | `/workspace/scratch/5724460028e4/EDBP-base` |
| Base branch / working tree | `main` / clean |
| Feature branch | `feature/flatpak-enterprise-integration` |
| Feature worktree | `/workspace/scratch/5724460028e4/EDBP-flatpak` |
| Implementation checkpoint commit | `b2107c6c6b7e26fd7c2def293e59a1c9e61a4ca2` |
| Working tree immediately after implementation checkpoint | PASS: clean; all 16 files committed |
| Documentation tip | Recorded separately in the accompanying preservation integrity record |
| Feature tracking branch | Unset to prevent an implicit push toward `main` |

The initial checkout was obtained directly from the requested upstream. Other
local repositories were inspected read-only and left untouched. The new clone's
initial `--no-checkout` state was populated before creating the separate worktree.
No reset, discard, force push, enterprise fork, enterprise modification, pull
request, or merge was performed.

## Implemented source behavior

- Explicit Debian Flatpak, public-key verification, session, portal, trust,
  desktop-export, icon, and MIME packages with APT Recommends disabled. KDE is
  retained as the selected portal backend.
- Official Flathub descriptor with embedded public signing material; descriptor
  and decoded-key SHA-256 values and the primary fingerprint are recorded in
  `trust.json`. Existing remote identity/signature drift is rejected before
  remote mutation. Commit and summary signature verification are required.
- Approved system app catalog: ONLYOFFICE
  (`org.onlyoffice.desktopeditors`), RustDesk (`com.rustdesk.RustDesk`), and Flatseal
  (`com.github.tchx84.Flatseal`), each on `x86_64/stable`.
- Acquisition filter permits those three apps and x86_64 runtime dependencies.
  Flatpak language selection explicitly includes Arabic and English.
- Online acquisition command targets a separately marked, private staging
  directory through an isolated system installation. It rejects non-root callers,
  the default host installation path, symlinks, and unrelated nonempty directories.
  Flatpak and GPG subprocesses use controlled environments. Apps are never launched.
- Acquired deployments can be inspected and recorded as actual full OSTree refs,
  64-character commit IDs, reported versions, runtimes, and metadata permissions.
  No fabricated installed-version manifest is checked into this repository.
- A Polkit rule denies Flatpak system-helper actions to non-root subjects,
  including the administrator's desktop session. Root management remains subject
  to existing password-required sudo controls. Other Polkit namespaces fall through.
- The image hook verifies required packages, configures system trust, and refuses
  to accept missing approved apps or runtimes. It performs no online acquisition.
- `make verify-flatpak` provides focused source checks without enterprise secrets
  or a complete ISO build; normal tree verification invokes the same checks.

## Changed files

| Path | Change |
| --- | --- |
| `Makefile` | Focused verification target |
| `REUSE.toml` | Flathub vendor-public-key provenance annotation |
| `THIRD_PARTY_NOTICES.md` | Descriptor/key provenance and interface references |
| `config/package-lists/applications.list.chroot` | Flatpak and GPG |
| `config/package-lists/desktop.list.chroot` | Explicit portal/session/export dependencies |
| `config/hooks/live/070-configure-flatpak.hook.chroot` | New image trust and payload acceptance gate |
| `config/includes.chroot_after_packages/etc/polkit-1/rules.d/00-edbp-flatpak-admin.rules` | New system-helper authorization rule |
| `config/includes.chroot_after_packages/usr/local/sbin/edbp-flatpak` | New trust, isolated acquisition, and inspection CLI |
| `config/includes.chroot_after_packages/usr/share/edbp/flatpak/approved-apps.json` | New approved app catalog |
| `config/includes.chroot_after_packages/usr/share/edbp/flatpak/flathub.filter` | New acquisition filter |
| `config/includes.chroot_after_packages/usr/share/edbp/flatpak/flathub.flatpakrepo` | Unmodified official descriptor |
| `config/includes.chroot_after_packages/usr/share/edbp/flatpak/trust.json` | New reviewed trust evidence |
| `scripts/verify-flatpak` | New source verification driver |
| `scripts/verify-tree` | Calls focused Flatpak checks |
| `tests/test-flatpak-integration` | New focused negative-path and policy tests |
| `FLATPAK_PHASE2.md` | This checkpoint report |

Existing administrative identity, SSH, firewall, USBGuard, OOBE, installer
configuration, native office packages, and institution-specific files were not
changed. New source contains no production credentials, private keys, institution
identity, or institution-specific network policy. The vendored key is public.

## Material commands executed

Read-only inspection included Git remotes, HEAD, branch, status, worktree and file
inventories; targeted source reads; upstream Flatpak 1.16.1 interface inspection;
official descriptor retrieval; and public-key inspection with GPG. Development
and verification commands included:

```bash
# From /workspace/scratch/5724460028e4
git clone --no-checkout https://github.com/Q-D-4/EDBP.git EDBP-base

# From the newly created EDBP-base clone
git remote -v
git rev-parse HEAD
git branch --show-current
git status --short
git fetch --prune origin
git checkout HEAD -- .
git worktree add -b feature/flatpak-enterprise-integration \
  /workspace/scratch/5724460028e4/EDBP-flatpak origin/main

# From EDBP-flatpak
git branch --unset-upstream
git worktree list --porcelain
git rev-parse HEAD origin/main
git status --porcelain=v1
git diff --check
PATH=/workspace/scratch/5724460028e4/tools/shellcheck-v0.11.0:$PATH make verify-flatpak
```

`make verify-flatpak` executes source/GPG validation, Python unit tests, `sh -n`
on the hook, `bash -n` on the driver, executable-mode checks, and ShellCheck.
The suite was repeated only after source corrections, including alignment with
Flatpak 1.16's partial-ref `list` output and the final environment/root guards.

`apt-get install --no-install-recommends --yes shellcheck` could not locate the
package. `apt-get update` failed because the environment cannot assume the `_apt`
identity. No host packages were installed. Official ShellCheck v0.11.0 was instead
retrieved into the scratch tools directory and SHA-256 verified against
`8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198`.
An initial archive extraction could not restore archive ownership; extraction
with `tar --no-same-owner` succeeded. This tool is outside the product source.

## Verification results

| Check | Result and scope |
| --- | --- |
| Base/main isolation | PASS: exact upstream, fresh fetch, clean base worktree |
| Official descriptor and key | PASS: checksum, decoded key checksum, actual GPG primary fingerprint |
| Focused unit/policy tests | PASS: 28 tests, zero skips; fake Flatpak responses and Node execution of the rule |
| Shell syntax / executable modes / ShellCheck | PASS |
| Whitespace and conflict-marker review | PASS |
| Changed-source secret-pattern review | PASS; reviewed source and public signing material only |
| Actual app acquisition / installed manifest | BLOCKED: Flatpak is not installed on this host |
| Debian 13 package resolution / target Polkit and portal behavior | NOT TESTED: this host is Ubuntu 24.04.3 |
| Real apps, sandbox behavior, offline payload and ISO | NOT TESTED |
| Full `make verify`, build or installer regression | NOT TESTED: only Phase 2 focused checks were authorized |

Trust evidence: Flathub descriptor SHA-256
`3371dd250e61d9e1633630073fefda153cd4426f72f4afa0c3373ae2e8fea03a`;
decoded key SHA-256
`8bdc20abc4e19c0796460beb5bfe0e7aa4138716999e19c6f2dbdd78cc41aeaa`;
primary fingerprint `6E5C05D979C76DAF93C081354184DD4D907A7CAE`.
Key rotation or expiry must be reviewed explicitly rather than bypassed.

## Outstanding risks and next checkpoint

1. Real Flatpak 1.16+ behavior, system installation isolation, Flathub remote
   configuration, signatures, dependency resolution, deployed apps, session
   integration, and actual Polkit dispatch still require checks on a suitable
   Debian 13 amd64 environment. Unit fixtures are not evidence of those behaviors.
2. Stable refs resolve online at acquisition time. The snapshot records deployed
   revisions but does not enforce an image lock; reproducible offline export,
   exact dependency closure, import and pinned-build validation belong to Phase 3.
3. Runtime allowance is intentionally broader than the eventual pinned closure.
   The filter is an acquisition restriction, not mandatory sandbox policy.
   The Polkit rule does not prevent per-user installs, updates or user overrides.
4. ONLYOFFICE hardening, system override policy, Flatseal restrictions, RustDesk
   unattended-access policy and real security acceptance remain later-phase work.
5. The image gate deliberately fails without the approved payload. This feature
   branch is not merge-ready and cannot yet produce an accepted release ISO.

The next checkpoint is completion of **Phase 2 real acquisition and focused
target checks**, with an actual deployment manifest on a Debian 13 amd64 host.
For an authorized operator there, the acquisition entry point is:

```bash
sudo python3 config/includes.chroot_after_packages/usr/local/sbin/edbp-flatpak \
  --assets "$PWD/config/includes.chroot_after_packages/usr/share/edbp/flatpak" \
  acquire-online --stage /absolute/new/private/staging-directory
```

Acquisition status: **BLOCKED**. This command was not executed because no suitable
Debian 13 validation environment was established. Phase 3 must not begin
automatically. A future PR must satisfy the repository's full applicable
verification, provenance and DCO requirements.

## Resume preservation and environment assessment — 2026-10-08

### Preservation evidence

| Check | Status | Verified result |
| --- | --- | --- |
| Exact worktree, origin, feature branch and original HEAD | PASS | Matched the authorized existing workspace; no new development clone or branch |
| Complete existing implementation | PASS | Exactly 6 modified and 10 new files; regular files, expected executable modes, no unintended files |
| Integrity before/after checkpoint commit | PASS | SHA-256 and modes matched for all 16 files |
| New-source secret and conflict-pattern review | PASS | No findings; reviewed public Flathub key material only |
| Local source checkpoint | PASS | `b2107c6c6b7e26fd7c2def293e59a1c9e61a4ca2`, signed off using the configured Codex identity |
| Main and other worktrees | PASS | Main stays clean at `de22642905d8073196471b580464c7fdfa5a21a6`; no downstream changes |
| Self-contained Git bundle | PASS | Complete reachable history; no external prerequisite commit; `git bundle verify` succeeded |
| Fresh bare-repository restore | PASS | Imported bundle, ran `git fsck --full --no-reflogs`, compared all 16 file hashes and Git modes |
| Persistent backup | PASS | `/EDBP-phase2-checkpoint-b2107c6c6b7e.tar.gz` saved and independently materialized from persistent storage |
| Persistent backup readback | PASS | Byte-for-byte equal; SHA-256 `a2de4ed18f0cc6c598f3cd7d9a95187a16ac6b203689b5a82849c42dec7023cc` |
| Prior source verification | PASS | Recorded 28 tests, zero skips, ShellCheck, syntax and trust checks retained; unchanged implementation did not justify rerunning the suite |

The initial durable archive contains a full Git bundle, precommit and checkpoint
integrity records, and recovery instructions. It preserves the original report
as well as the complete implementation. A refreshed transferable archive also
records this documentation update and the environment assessment. Its integrity
record identifies the final feature tip; its external checksum identifies the
archive bytes without a self-referential checksum. Neither archive contains
Flatpak application payloads or Phase 3 offline export work.

### Target environment evidence

| Observation | Status | Evidence |
| --- | --- | --- |
| Host identification | PASS | Ubuntu 24.04.3 LTS; `x86_64`; kernel `6.18.44` |
| Debian 13 environment | BLOCKED | No Debian VM/container was established |
| Existing container/VM tooling | BLOCKED | Docker, Podman, containerd CLI, LXC, systemd-nspawn, QEMU and libvirt executables absent; runtime sockets and `/dev/kvm` absent |
| Process privilege inventory | PASS | All capability masks zero; `NoNewPrivs=1`; seccomp mode 2; UID/GID mapping contains only UID/GID 0 |
| Root-mapped user namespace probe | BLOCKED | `unshare --user --map-root-user -- /usr/bin/true` exited 1: `write failed /proc/self/uid_map: Operation not permitted` |
| Bubblewrap namespace/mount probe | BLOCKED | `bwrap --unshare-user --unshare-pid --ro-bind / / --proc /proc --dev /dev -- /usr/bin/true` did not complete within 10 seconds; probe was terminated |
| Flatpak executable | BLOCKED | Not installed |

Two focused namespace probes were attempted; no repeated provisioning attempts,
capability escalation, host package installation, seccomp changes, or namespace
workarounds were performed. There is no supported validation runtime available
with the installed tools. The absence of KVM alone does not prove software
emulation impossible; QEMU software emulation was **NOT TESTED**, and no QEMU
environment was provisioned. An extracted Debian filesystem or a simulated
Flatpak executable would not meet the requested runtime acceptance criteria.

### Acquisition and focused target acceptance

| Requested check | Status | Result |
| --- | --- | --- |
| Source Flathub identity/key/descriptor | PASS | Unchanged reviewed assets and hashes retained in the verified checkpoint |
| Installed Flathub remote and GPG requirements | NOT TESTED | No actual target installation |
| Actual Flatpak 1.16+ CLI behavior | NOT TESTED | Target environment unavailable |
| System scope and acquisition isolation | NOT TESTED | Acquisition tooling preserved; not executed against a real target |
| `org.onlyoffice.desktopeditors` acquisition | BLOCKED | No app downloaded or installed; version/OSTree commit unknown |
| `com.rustdesk.RustDesk` acquisition | BLOCKED | No app downloaded or installed; version/OSTree commit unknown |
| `com.github.tchx84.Flatseal` acquisition | BLOCKED | No app downloaded or installed; version/OSTree commit unknown |
| Required runtimes/extensions and dependency resolution | NOT TESTED | No deployed refs exist from this validation attempt |
| Architecture, full refs and effective installed metadata | NOT TESTED | No target installation to inspect |
| Actual deployment manifest | BLOCKED | Not generated; no fabricated versions, runtimes or commit hashes |
| Debian 13 package availability/dependency resolution | NOT TESTED | No Debian 13 package manager environment |
| Image acceptance gate preservation | PASS | Original hook unchanged; SHA-256 `10f90bc4dcd4f0618f77a2c1b6c7e009d95acd2b8f0be488a16ac726a9af4082`; original focused source evidence retained |
| Image gate execution in Debian 13 | NOT TESTED | No target chroot; no gate bypass or ISO build |
| Actual Polkit system dispatch | NOT TESTED | Prior Node rule tests remain source evidence only |
| KDE portal package configuration | PASS | Existing source configuration unchanged; KDE backend retained |
| KDE graphical session, portal routing and app launch | NOT TESTED | No target graphical session |
| Phase 2 runtime acceptance | BLOCKED | Target environment and actual acquisition evidence still required |

The precise next checkpoint is a Debian 13 Trixie amd64 validation host or VM
with Flatpak 1.16+, root-managed isolated staging, supported Bubblewrap/user
namespaces, GPG, and sufficient storage/network access to Flathub. Restore the
verified feature checkpoint without overwriting other work, then run the existing
acquisition tooling and record actual app/runtime/extension refs, versions,
OSTree commits, trust and installed metadata. Graphical acceptance requires a
separate real KDE session; a CLI-only environment cannot establish it.

Stop at this Phase 2 blocker pending explicit approval and a suitable environment.
No push, pull request, merge, enterprise modification, ISO build, offline locking,
or payload export was performed.

---

## Debian 13 Acquisition Checkpoint — 2026-10-08

### Validation Environment

- OS: Debian 13.7 Trixie, x86_64
- Flatpak: 1.16.6
- Bubblewrap: 0.12.0
- Desktop: KDE Plasma / X11
- xdg-desktop-portal: 1.20.3
- xdg-desktop-portal-kde: 6.3.5
- Polkit: 126

### Verified Results

- PASS: Official Flathub source verification.
- PASS: Isolated Flatpak acquisition.
- PASS: ONLYOFFICE 9.4.0.
- PASS: RustDesk 1.5.0.
- PASS: Flatseal 2.4.1.
- PASS: Twelve deployment refs, including nine runtimes/extensions.
- PASS: Actual OSTree commits recorded in manifest.
- PASS: Default host system Flatpak installation remains empty.
- PASS: Staging directory restricted to root.
- PASS: KDE portal backend active on D-Bus.
- PASS: FileChooser interface version 4.
- PASS: Print interface version 3.
- PASS: Manifest backed up.
- PASS: Complete staging backup verified by rsync checksum comparison.
- PASS: Git worktree clean before documentation update.

### Preserved Artifacts

Staging backup:
`<local-workspace>/flatpak-stage-preserved-18fd6036`

Manifest:
`<local-workspace>/installed-manifest-phase2.json`

Manifest SHA-256:
`caa98a0d17bc5e17645c19665fd78c19ee69f7ef2027f34194cfdb05479c603a`

The staging copy is preserved on the same physical machine.
It is not yet a verified portable offline repository.

### Remaining Verification

- NOT TESTED: Actual Polkit authorization behavior.
- NOT TESTED: Graphical application execution.
- NOT TESTED: ONLYOFFICE document workflows and printing.
- NOT TESTED: RustDesk remote-control functionality.
- NOT TESTED: End-to-end portal workflows.
- NOT TESTED: ISO and installer integration.
- NOT TESTED: Offline payload import and pinned revisions.

### Acceptance Status

Phase 2 source verification: PASS.
Phase 2 application acquisition: PASS.
Phase 2 full runtime acceptance: PARTIAL.
Phase 3: NOT STARTED.

No push, PR, merge, or enterprise downstream changes performed.
