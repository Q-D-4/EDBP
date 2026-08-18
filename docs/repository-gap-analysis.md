# EDBP Repository Gap Analysis

Date: 2026-08-18

This report distinguishes the remote baseline, the integrated local work, and
the remaining release work:

1. GitHub `origin/main` at `194a9b9` (`VERSION=2.2.0`).
2. Local branch `feature/layer-02`, based exactly on that commit and containing
   the reviewed layer-02 worktree changes.
3. The unimplemented layers required before an ISO can be released.

## 1. Repository state

- The local branch has been fast-forwarded to `origin/main` at `194a9b9`; there
  is no remaining history divergence or version downgrade.
- GitHub currently contains `auto/config` and the Bluetooth kernel-module
  policy. The local feature branch adds the repositories, package lists,
  USBGuard policy, approved nftables file, and layer-02 hooks; GitHub remains
  unchanged until that branch is committed and pushed.
- Local `auto/config` deliberately changes `--apt-recommends` from `true` to
  `false`; operational recommendations are promoted to explicit packages.
- `VERSION` is now consistently 2.2.0 in the integrated worktree. README still
  points to a v2.1.0 legacy runbook, and that file labels itself v2.0.2; those
  documents must not be treated as the current executable specification.
- `EDBP-Implementation-Runbook-v2.1.0.md` is malformed: it starts with the word
  `Markdown`, contains only three code fences, and has multiple shell/config
  fragments collapsed onto the same lines. It is not an executable source of
  truth and must be marked legacy or replaced.
- There are no tags, releases, CI workflows, build controller, changelog, or
  release manifest in GitHub.

## 2. Implemented locally, not yet on GitHub

- Minimal Plasma/SDDM desktop package list.
- LibreOffice Arabic/productivity and approved font package list.
- Complete Debian Trixie `printer-driver-all` expansion, HPLIP, Epson ESC/P-R,
  CUPS, SANE, AirScan, and Simple Scan.
- Brave and Element vendor repositories, scoped keyrings, runtime sources, and
  APT origin/package pinning.
- Brave global-trust cleanup for current and future keyring upgrades.
- USBGuard class policy, restricted `sudo` IPC ACL, Debian `plugdev` cleanup,
  D-Bus bridge disablement, and Live-session start guard.
- Cybersecurity-supplied nftables ruleset, copied byte-for-byte.
- Full Bluetooth module denial policy; no USB-storage kernel blacklist.
- Explicit Live-session user, locale, and keyboard runtime dependencies while
  global APT recommendations remain disabled.
- Dependency resolution simulation for all direct packages.

## 3. Completed integration prerequisite

### Safe Git reconciliation

The old local work was archived, the branch was fast-forwarded to the current
`origin/main`, the single `.gitignore` overlap was resolved, `VERSION=2.2.0`
was retained, and the layer-02 changes were reapplied on
`feature/layer-02`. A backup stash and checksum-addressed tar archive are kept
until the feature branch is committed and reviewed.

## 4. Remaining release blockers (P0)

### P0.1 — Partial Preseed for the interactive installer

`config/includes.binary/preseed.cfg` is absent. The new file must not reuse the
obsolete automatic-wipe recipe from the runbooks. It should preconfigure only
safe defaults and identity behavior while leaving partition selection and the
final destructive confirmation interactive.

Required decisions:

- whether disk encryption is mandatory, optional, or prohibited;
- how `localadmin` receives a unique local password;
- installation timezone/domain defaults;
- how the administrative SSH public key is injected without a private key or
  shared password in Git.

Recommended password model: prompt for a unique `localadmin` password in the
interactive installer, disable SSH password authentication, and use public-key
authentication remotely. Baking one password hash into an ISO for 600–6,000
machines is not acceptable.

### P0.2 — Identity, SSH, and first-boot OOBE

None of the following exists:

- `localadmin` creation contract;
- SSH `sshd_config.d` hardening and key installation;
- SDDM `HideUsers=localadmin` configuration;
- one-time hostname and standard-user OOBE;
- atomic completion marker, validation, rollback, and recovery path;
- guarantee that the daily user is not in `sudo` or another privileged group.

The OOBE must run before SDDM. Otherwise hiding `localadmin` can leave a fresh
machine with an empty login screen. A TTY/whiptail wizard is smaller and safer
than a privileged graphical wizard; this is an explicit UX/security decision.

OpenSSH host-key cloning is handled by the Debian Trixie live-build normal hook
`8050-remove-openssh-server-host-keys.hook.chroot` and regeneration paths, but
the finished ISO still needs an automated uniqueness test across two installs.

### P0.3 — nftables acceptance issues

The approved file is present and unchanged, but it has unresolved behavior:

- no explicit DHCP client broadcast path;
- all new IPv6 traffic is denied;
- every RFC1918 source may initiate every input protocol;
- it filters by address ranges, not by an interface whitelist;
- stopping `nftables.service` flushes the whole ruleset, not only the external
  traffic restriction.

These are governance decisions, not syntax defects that may be silently fixed.
DHCP and the approved Connected-mode behavior must be tested and signed off.

### P0.4 — No successful end-to-end artifact yet

No complete `lb build` result has been accepted. Missing acceptance tests:

- UEFI-only boot and absence of a legacy BIOS path;
- Secure Boot with OVMF when signed components are available;
- Live session and graphical installer entry;
- interactive disk confirmation on NVMe, SATA SSD, and HDD;
- installed-system boot, OOBE, SDDM, SSH, nftables, and USBGuard;
- uniqueness of machine-id and SSH host keys across two installations;
- ISO checksum, package manifest, and provenance metadata.

## 5. Functional gaps (P1)

### Desktop and localization

- persistent `/etc/default/locale`, `locale.gen`, and `/etc/default/keyboard`;
- KDE `us,ara` layout with left/right Alt+Shift for new users;
- SDDM English locale and keyboard behavior;
- approved wallpaper asset and Plasma defaults;
- decision on Baloo indexing and KDE usage/feedback collection.

Kernel boot parameters alone do not configure every installed KDE user.

### Brave

`/etc/brave/policies/managed/policies.json` is absent. It must define the home
button, startup URLs, and DuckDuckGo search provider. The portal URL scheme and
trust chain are unresolved: if `home.mofa.sy` uses an internal HTTPS CA, that CA
must be deployed system-wide; falling back silently to HTTP is not acceptable.

### LibreOffice

Missing:

- Arabic UI selection;
- Notebookbar/Tabbed interface selection;
- DOCX/XLSX/PPTX default save formats;
- Microsoft Office MIME associations;
- a first-launch validation test using a clean user profile.

Installing `libreoffice-l10n-ar` only makes Arabic available; it does not select
Arabic or the Notebookbar automatically.

### Terminal history

The requested history disablement is not implemented. Disabling history for
`localadmin` is anti-forensic and weakens incident response. A defensible split
is to disable interactive shell history only for standard users while retaining
protected administrative history and/or audited privileged sessions.

### Printers and scanners

Package coverage is broad but cannot guarantee the stated 25+ models without a
model/VID/PID inventory:

- some HP devices require the proprietary HPLIP plug-in, unavailable from the
  isolated Debian image by default;
- newer Epson models may require ESC/P-R2 vendor packages;
- many scanners/MFPs expose vendor-specific USB class `ff`, which the generic
  USBGuard class policy correctly blocks;
- docks and USB hubs require explicit testing under the strict USBGuard policy.

### Service policy

Only nftables and USBGuard are explicitly enabled, and usbguard-dbus is
disabled. Missing reviewed policy/configuration for:

- `ssh.service`;
- CUPS and `cups-browsed`;
- Avahi interface/protocol restrictions;
- `ipp-usb`;
- NetworkManager and Wi-Fi policy;
- unused `saned` service/socket;
- APT periodic timers in Isolated versus Connected mode;
- internal DNS and NTP behavior.

## 6. Security and fleet-management gaps (P1/P2)

- AppArmor enforcement/profile validation is not defined.
- PAM password quality, lockout, and local account policy are not defined.
- Audit policy and privileged-session logging are not defined.
- Kernel/sysctl hardening has not been designed against desktop/peripheral
  compatibility.
- There is no enterprise CA deployment path.
- There is no staged update policy, local mirror/proxy implementation, rollback
  policy, or endpoint compliance reporting.
- Direct vendor repositories are functional but do not produce reproducible
  builds across dates. A controlled snapshot/mirror is required before fleet
  scale.
- There is no SBOM/package manifest retention, release signing, or immutable
  mapping from Git commit to ISO hash.
- Full-disk encryption is not defined. For a sensitive workstation fleet this
  must be an explicit accepted or rejected control, not inherited from a legacy
  runbook.

## 7. Recommended execution order

1. Commit and review the integrated layer-02 feature branch.
2. Implement the partial interactive Preseed and identity contract.
3. Implement SSH hardening, SDDM hiding, and the one-shot OOBE.
4. Add persistent locale/keyboard, Brave, LibreOffice, MIME, and KDE policies.
5. Review and harden the daemon/service layer.
6. Add build validation, UEFI/QEMU tests, manifests, checksums, and release
   provenance.
7. Run a hardware pilot using the real printer/scanner/USB inventory.
