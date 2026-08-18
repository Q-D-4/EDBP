# EDBP v2.2.0 — Enterprise Debian Build Platform Specification

**Document class:** Normative architecture, build, security, and acceptance specification

**Target:** Debian 13 (Trixie), amd64, UEFI-only enterprise workstations

**Build framework:** Debian `live-build`

**Image model:** Hybrid Live ISO + graphical Debian Installer

**Desktop:** Minimal KDE Plasma 6 with SDDM

**Version source:** `VERSION`
**Specification status:** Code-complete release candidate; Golden Master status
requires every release gate in this document to pass.

---

## 1. Normative language and engineering status

The terms **MUST**, **MUST NOT**, **SHOULD**, and **MAY** are normative.

This repository is the executable source for an EDBP image, but the presence of
configuration files is not evidence that an ISO is production-safe. A build is
a **Golden Master** only after:

1. the source tree is committed and clean;
2. `make verify` and `make all` pass;
3. the generated checksums and manifest are retained;
4. two independent UEFI installations pass the VM and forensic tests;
5. the cybersecurity owner accepts the documented nftables limitations;
6. the actual printer, scanner, hub, dock, and USB VID/PID inventory passes a
   hardware pilot;
7. the shared-password exception has an owner, vault record, expiry date,
   rotation/recovery procedure, and tested replacement path.

No plaintext administrator password, password hash, SSH private key, or API
token may be committed. As a time-bounded deployment exception, the build
controller reads a shared `localadmin` crypt(3) hash from an ignored mode-0600
file and renders it into the installer preseed. The hash is consequently
embedded in the installer initrd and is extractable for offline attack; it is
not equivalent to a secret-management system. Only reviewed ED25519 public
keys and the explicitly supplied password hash are injected at build time.

### 1.1 Deliberate path corrections

- LibreOffice administrator policy is
  `/etc/libreoffice/registry/edbp-defaults.xcd`. An `.xcu` file is a user-layer
  registry fragment and is not the correct system-wide extension format.
- OOBE is `/usr/local/sbin/edbp-oobe`. It is a root-only system
  administration program and therefore does not belong in `/usr/local/bin`.
- The OOBE service disables normal enablement after success but does not delete
  its packaged unit. `/var/lib/edbp/oobe-complete` is the authoritative,
  atomic completion guard.

---

## 2. Scope and deployment assumptions

| Property | Normative value |
|---|---|
| Fleet size | 600 workstations, scalable to 6,000 |
| CPU | Intel/AMD x86-64, seventh generation or newer |
| Memory | 4 GiB minimum |
| Storage | NVMe, SATA SSD, or HDD |
| Firmware | UEFI only; legacy BIOS intentionally unsupported |
| Secure Boot | `auto`; signed Debian shim/GRUB used when available |
| Default network profile | Isolated LAN-only |
| External internet exception | Temporary `systemctl stop nftables.service` |
| Update source | Debian/vendor HTTPS repositories or future internal mirror |
| Installed administrator | `localadmin`, build-injected shared console/sudo password, SSH key-only |
| Daily user | Created by OOBE; no sudo; `scanner` is the sole supplementary group |
| UI language | English |
| LibreOffice UI | Arabic, Tabbed Notebookbar |
| Keyboard | `us,ara`, both Alt+Shift combinations through XKB group option |

Full-disk encryption is not silently enabled or rejected by this repository.
The installer leaves partitioning interactive. Fleet governance MUST decide
whether LUKS is mandatory before Golden Master approval.

---

## 3. Layered architecture

### Layer 01 — Boot, kernel, initramfs

- amd64 only;
- `iso-hybrid` image with `grub-efi` only;
- Debian Live initramfs through `live-boot`;
- graphical Debian Installer included with `--debian-installer live`;
- Secure Boot support selected automatically;
- Bluetooth kernel modules denied by boot arguments, modprobe blacklist, and
  explicit `install /bin/false` rules;
- USB storage kernel modules are **not** blacklisted because USBGuard must be
  able to grant a root-authorized runtime exception.

### Layer 02 — Packages, repositories, daemons, security policy

- explicit package lists with APT Recommends disabled;
- scoped Brave and Element keyrings, runtime sources, and package pinning;
- nftables Isolated profile enabled by default;
- USBGuard class policy and `sudo` group IPC delegation;
- minimal Plasma, broad printer/scanner support, LibreOffice, Brave, Element,
  KeePassXC Minimal, and Simple Scan.

### Layer 03 — Desktop, identity, managed application policy, OOBE

- SDDM hides `localadmin` from the chooser;
- password-required sudo policy;
- managed Brave and LibreOffice defaults;
- immutable KDE keyboard and locale defaults;
- transactional first-boot hostname and daily-user provisioning.

### Layer 04 — Installer, SSH enrollment, final hooks, automation

- partial initrd preseed that never selects or confirms a disk;
- build-time `localadmin` password-hash injection with no password prompt;
- build-time ED25519 public-key injection;
- per-install SSH host-key generation;
- SSH public-key-only hardening;
- service validation, cache cleanup, checksum and provenance generation.

---

## 4. Complete repository tree

Generated `live-build` state, build directories, ISO artifacts, checksums,
local secret inputs, and staged installer inputs are intentionally ignored.

```text
EDBP/
├── .gitattributes
├── .gitignore
├── EDBP-v2.2.0-SPECIFICATION.md
├── Makefile
├── README.md
├── VERSION
├── auto/
│   └── config
├── config/
│   ├── archives/
│   │   ├── 00-edbp-trust-scope.conf
│   │   ├── brave-browser-release.list.binary
│   │   ├── brave-browser.key
│   │   ├── brave-browser.list.chroot
│   │   ├── brave-browser.pref
│   │   ├── element-io.key
│   │   ├── element-io.list.binary
│   │   ├── element-io.list.chroot
│   │   └── element-io.pref
│   ├── hooks/
│   │   └── live/
│   │       ├── 010-harden-usbguard-package-defaults.hook.chroot
│   │       ├── 020-remove-brave-global-trust.hook.chroot
│   │       ├── 030-enable-isolated-security-profile.hook.chroot
│   │       ├── 040-configure-desktop-identity.hook.chroot
│   │       ├── 050-validate-security-assets.hook.chroot
│   │       ├── 060-configure-network-services.hook.chroot
│   │       └── 090-clean-image.hook.chroot
│   ├── includes.installer/
│   │   ├── edbp-late-command
│   │   └── preseed.cfg.in
│   ├── includes.chroot_after_packages/
│   │   ├── etc/
│   │   │   ├── brave-origin/policies/managed/policies.json
│   │   │   ├── default/keyboard
│   │   │   ├── libreoffice/registry/edbp-defaults.xcd
│   │   │   ├── locale.conf
│   │   │   ├── locale.gen
│   │   │   ├── modprobe.d/90-edbp-disable-bluetooth.conf
│   │   │   ├── nftables.conf
│   │   │   ├── sddm.conf.d/hide-admin.conf
│   │   │   ├── ssh/sshd_config.d/10-edbp-hardening.conf
│   │   │   ├── sudoers.d/localadmin
│   │   │   ├── systemd/system/
│   │   │   │   ├── edbp-oobe.service
│   │   │   │   ├── sddm.service.d/10-edbp-oobe.conf
│   │   │   │   ├── usbguard-dbus.service.d/10-edbp-deny-activation.conf
│   │   │   │   └── usbguard.service.d/10-skip-live-session.conf
│   │   │   ├── usbguard/
│   │   │   │   ├── IPCAccessControl.d/:sudo
│   │   │   │   ├── rules.conf
│   │   │   │   └── usbguard-daemon.conf
│   │   │   └── xdg/
│   │   │       ├── baloofilerc
│   │   │       ├── kxkbrc
│   │   │       ├── mimeapps.list
│   │   │       ├── plasmarc
│   │   │       └── plasma-localerc
│   │   └── usr/
│   │       ├── local/sbin/edbp-oobe
│   │       └── share/
│   │           ├── keyrings/
│   │           │   ├── brave-browser-archive-keyring.gpg
│   │           │   └── element-io-archive-keyring.gpg
│   │           └── wallpapers/EDBP/
│   │               ├── metadata.json
│   │               └── contents/images/1920x1080.jpg
│   └── package-lists/
│       ├── applications.list.chroot
│       ├── desktop.list.chroot
│       ├── hardware-printers.list.chroot
│       ├── identity-oobe.list.chroot
│       ├── installer-launcher.list.chroot_live
│       ├── live-runtime.list.chroot
│       ├── productivity.list.chroot
│       └── security-core.list.chroot
└── scripts/
    ├── stage-admin-keys
    ├── stage-localadmin-password
    └── verify-tree
```

The local source inputs and generated installer files below MUST NOT be
tracked:

```text
secrets/localadmin_authorized_keys
secrets/localadmin_password_hash
config/includes.installer/localadmin_authorized_keys
config/includes.installer/preseed.cfg
edbp-2.2.0-amd64.build-inputs.json
```

---

## 5. Build-controller contract

`auto/config` resolves the repository root independently of the caller's
current directory and validates `VERSION`. Its critical values are:

| live-build option | Value | Reason |
|---|---|---|
| `--distribution` | `trixie` | Debian 13 |
| `--architecture` | `amd64` | Fleet baseline |
| `--binary-image` | `iso-hybrid` | Optical/USB boot artifact |
| `--bootloaders` | `grub-efi` | UEFI-only boot path |
| `--uefi-secure-boot` | `auto` | Use signed chain when available |
| `--debian-installer` | `live` | Install the reviewed Live filesystem |
| `--debian-installer-gui` | `true` | Graphical installer |
| `--archive-areas` | `main non-free-firmware` | Base plus firmware |
| `--apt-recommends` | `false` | Deterministic minimal package closure |
| `--checksums` | `sha256` | Media integrity metadata; D-I also adds MD5 as required |
| SquashFS compression | `xz` | Minimum image size, slower build/boot decompression |

`config/includes.installer/preseed.cfg.in` is the tracked, secret-free source.
The build controller renders `config/includes.installer/preseed.cfg`, which is
copied to the root of both installer initrds. Debian Installer automatically
loads a root-level `preseed.cfg`; a `preseed/file=/cdrom/...` argument is
therefore neither needed nor correct for this layout.

Build and runtime Debian mirror URLs are overridable using:

```text
EDBP_BUILD_MIRROR
EDBP_BUILD_SECURITY_MIRROR
EDBP_RUNTIME_MIRROR
EDBP_RUNTIME_SECURITY_MIRROR
EDBP_ISO_PUBLISHER
```

This supports a future local APT mirror without changing tracked source.

---

## 6. Repository and APT trust model

### 6.1 Source ownership

| Repository | Build source | Installed source | Eligible packages |
|---|---|---|---|
| Debian | `auto/config` mirrors | generated Debian sources | Debian archive packages |
| Brave | `brave-browser.list.chroot` | `brave-browser-release.list.binary` | `brave-origin`, `brave-keyring` |
| Element | `element-io.list.chroot` | `element-io.list.binary` | `element-desktop`, `element-io-archive-keyring` |

Every vendor source uses `Signed-By`. `live-build` uses two distinct archive
passes and can temporarily expose the chroot and binary source entries in the
same APT invocation. Each repository therefore has one unsuffixed `*.key`
input shared by both passes, and both source entries reference the same
generated path under `trusted.gpg.d`. Stage-suffixed duplicate keys are
forbidden because they produce different `Signed-By` values for the same
URI/suite and APT rejects the source set as ambiguous.

`00-edbp-trust-scope.conf` excludes `trusted.gpg.d` from global trust: only
Debian's archive keyring and administrator keyrings under `/etc/apt/keyrings`
are globally eligible. Vendor keys remain usable solely through their explicit
source paths. Pin files first allow only the reviewed package names at priority
500 and then assign priority `-1` to every other package from that origin.
Nightly/beta packages are not eligible.

### 6.2 Keyring checksums

| Keyring | Primary fingerprint | SHA-256 |
|---|---|---|
| Brave | `DBF1 A116 C220 B8C7 164F 9823 0686 B784 2003 8257` | `c85e85aa3d1783ffaa649ee8dbbc22af7f87192d304602d37e3018226b394788` |
| Element | `12D4 CD60 0C22 40A9 F4A8 2071 D7B0 B669 41D0 1538` | `c2cb0c6bf269c56158e3c0ae8185cbeee168db5071bef659b97b1a775ebc1955` |

`brave-keyring` may create a compatibility symlink in global APT trust. In
addition, the reviewed Brave Origin 1.93 package currently generates a second
Deb822 source for Google's Chrome repository and an associated key under
`/usr/share/keyrings`. Neither object belongs to the EDBP trust model. Hook
`020` accepts only the reviewed shapes, removes them, and aborts on drift. The
tracked Brave repository remains the sole update path. Hook `050` verifies the
final scoped keyring bytes and confirms that the additional Origin source and
key did not survive.

Direct rolling vendor repositories are not reproducible across dates. A fleet
release SHOULD use a snapshot or controlled internal mirror and retain the
generated `.packages` manifest.

---

## 7. Package inventory and dependency ownership

APT Recommends are disabled globally. Every operational recommendation needed
by the workstation role is promoted into a tracked package list.

### 7.1 Desktop

| Function | Explicit packages |
|---|---|
| Plasma/SDDM | `plasma-desktop`, `sddm`, `sddm-theme-breeze`, `xserver-xorg` |
| Plasma operations | `kscreen`, `plasma-nm`, `plasma-pa`, `powerdevil`, `systemsettings`, `xdg-desktop-portal-kde`, `kio-extras` |
| User shell | `dolphin`, `konsole`, `ark`, `kate`, `7zip`, `bzip2`, `unzip`, `zip` |
| Network | `network-manager`, `wpasupplicant`, `wireless-regdb` |
| Audio | `pipewire`, `pipewire-pulse`, `pipewire-alsa`, `wireplumber` |

`task-kde-desktop`, `kde-standard`, Discover, games, PIM, Welcome, BlueDevil,
and `pipewire-audio` are excluded. `pipewire-audio` would hard-depend on the
Bluetooth SPA plugin in Debian 13.

### 7.2 Productivity and fonts

| Function | Explicit packages |
|---|---|
| Office | `libreoffice-writer`, `libreoffice-calc`, `libreoffice-impress`, `libreoffice-math` |
| KDE integration | `libreoffice-kf6`, `libreoffice-plasma`, `libreoffice-style-breeze` |
| Arabic | `libreoffice-l10n-ar`, `hunspell-ar`, `mythes-ar` |
| Fonts | `fonts-noto-core`, `fonts-noto-color-emoji`, `fonts-liberation`, `fonts-liberation-sans-narrow`, `fonts-croscore`, `fonts-crosextra-caladea`, `fonts-crosextra-carlito`, `fonts-sil-scheherazade` |

`fonts-noto-extra` is intentionally excluded because its installed footprint is
not justified by the English/Arabic role.

### 7.3 Applications

| Application | Package and rationale |
|---|---|
| Brave Origin | `brave-origin`; official standalone minimal Linux build, updated only through the pinned Brave repository |
| Element | `element-desktop`; no homeserver/account preconfiguration |
| KeePassXC | `keepassxc-minimal`; browser integration, SSH agent, networking, and Secret Service features excluded |
| Icons | `fonts-font-awesome`; explicit KeePassXC UI dependency |

### 7.4 Printing and scanning

| Function | Explicit packages |
|---|---|
| Print core | `cups`, `cups-client`, `cups-filters`, `cups-browsed`, `cups-pk-helper` |
| Discovery/UI | `avahi-daemon`, `libnss-mdns`, `ipp-usb`, `print-manager`, `system-config-printer-udev` |
| Drivers | `printer-driver-all` plus every Trixie driver named in `hardware-printers.list.chroot` |
| HP | `hplip`, `hplip-gui`, `printer-driver-hpcups`, `printer-driver-postscript-hp` |
| Epson | `printer-driver-escpr` |
| Scanners | `sane-utils`, `sane-airscan`, `simple-scan` |

`printer-driver-all` contains drivers as Recommends, so its Trixie set is
expanded explicitly. Proprietary HP plug-ins and Epson ESC/P-R2 packages are
not universal and require a model-specific signed-package review.

### 7.5 Security, identity, and Live runtime

| List | Packages |
|---|---|
| Security | `usbguard`, `nftables`, `openssh-server`, `sudo`, `ca-certificates` |
| OOBE | `whiptail`, `passwd`, `python3-minimal`, `kbd` |
| Live runtime | `user-setup`, `locales`, `keyboard-configuration` |
| Live-only installer UI | `debian-installer-launcher`; `_live` suffix causes removal from installed target |

---

## 8. Kernel and Bluetooth denial

Bluetooth is denied at three points:

1. `module_blacklist=bluetooth,btusb` on Live and Installer kernel command
   lines;
2. aliases blacklisted for `bluetooth`, `btusb`, vendor transport modules,
   HCI UART, BNEP, RFCOMM, and HIDP;
3. explicit `install /bin/false` for the primary load paths.

`bluez`, `bluedevil`, and `libspa-0.2-bluetooth` are forbidden packages.

Verification on an installed machine:

```bash
dpkg-query -W bluez bluedevil libspa-0.2-bluetooth 2>&1
sudo modprobe bluetooth && echo FAIL || echo PASS
sudo modprobe btusb && echo FAIL || echo PASS
lsmod | grep -E '^(bluetooth|btusb)\b' && echo FAIL || echo PASS
```

---

## 9. USBGuard policy

USB Mass Storage and UAS are controlled exclusively by USBGuard. Kernel module
blacklisting is forbidden because it would prevent even root from granting an
approved exception.

### 9.1 Class rule

```text
block with-interface one-of { 08:*:* }
allow with-interface match-all { 03:*:* 06:*:* 07:*:* }
```

The first rule explicitly blocks any device exposing a Mass Storage interface
(`08`), including composite devices. The second rule requires the complete
interface set of every allowed device to be a subset of:

| Class | Meaning |
|---|---|
| `03` | HID keyboard/mouse |
| `06` | Still imaging/scanner |
| `07` | Printer |

An unconditional `allow` rule is forbidden: it would permit every non-storage
USB class and convert the policy from an allowlist into a broad blocklist. All
unmatched devices inherit `ImplicitPolicyTarget=block`. The rules are embedded
in the image and loaded when `usbguard.service` starts; they are not appended
after boot, which avoids an unenforced race window.

### 9.2 Daemon behavior

- present and newly inserted devices are evaluated against policy;
- controllers keep their state;
- default kernel authorization is `none`;
- audit output is written to `/var/log/usbguard/usbguard-audit.log`;
- USBGuard does not start in a USB-booted Live session because that would deny
  the class-08 boot medium.

### 9.3 IPC delegation

Root has full IPC access. The `sudo` group may:

- list/listen/modify device authorization;
- list policy;
- listen for exception events.

It cannot arbitrarily rewrite policy. Temporary administrator exception:

```bash
sudo usbguard list-devices
sudo usbguard allow-device DEVICE_ID
```

Use `--permanent` only after change approval because it writes a device rule.

External USB hubs use class `09` and are not generically allowed. Docks and
vendor-specific scanner class `ff` devices require explicit inventory rules;
this is a mandatory hardware acceptance item.

---

## 10. nftables Isolated profile

The tracked file is the cybersecurity-supplied artifact. Its normative hash is:

```text
04f5ff6be56fe60acd6b7ee031832b41e8671ae09c42ba141b91da04f0e0114a
```

`.gitattributes` preserves its approved terminal whitespace. Build hooks check
the hash and nftables syntax rather than silently rewriting the rules.

### 10.1 Effective policy

- loopback accepted;
- established/related state accepted;
- input accepted from all RFC1918 and IPv4 link-local sources;
- output accepted to all RFC1918 and IPv4 link-local destinations;
- forwarding dropped;
- all other new input/output dropped;
- new IPv6 traffic is dropped unless it is loopback or established/related.

This is address-range filtering, **not an interface whitelist** and **not a
port whitelist**. Every listening service is reachable from any accepted
private source address. That distinction is security-relevant.

### 10.2 Service/port exposure table

| Port/protocol | Owner | Isolated-profile behavior |
|---|---|---|
| 22/TCP | OpenSSH | Reachable from any accepted private source; key-only `localadmin` |
| 53/TCP+UDP | Resolver | Allowed only when DNS destination is in accepted private ranges |
| 67/68 UDP | DHCP | Initial output to `255.255.255.255` is dropped; DHCP cannot be assumed to work |
| 80/443 TCP | APT/Brave/Element/Matrix | Allowed only to private destinations; external internet denied |
| 123/UDP | NTP | Allowed only to private destinations |
| 631/TCP | CUPS/IPP | Subject to CUPS listen configuration; LAN source range is not port-filtered |
| 631/UDP | CUPS browsing | Private-source input may pass; broadcast output is dropped |
| 5353/UDP | Avahi/mDNS | Private-source input may pass; output to `224.0.0.251` is dropped |
| 3702/UDP | WSD scanner discovery | Private-source input may pass; output to `239.255.255.250` is dropped |

### 10.3 Connected exception

Debian's `nftables.service` flushes the ruleset on stop. The approved temporary
internet exception is therefore:

```bash
sudo systemctl stop nftables.service
sudo nft list ruleset
```

Re-enter Isolated mode immediately after the approved task:

```bash
sudo systemctl start nftables.service
sudo nft --check --file /etc/nftables.conf
sudo nft list ruleset
```

Do not disable the unit: a normal reboot must return to Isolated mode.

### 10.4 Blocking acceptance issue

The current rules have no DHCP/broadcast/multicast exception and no
interface-name filter. Consequently DHCP and active mDNS/WSD/CUPS discovery
are not valid Plug-and-Play claims under the default profile. Passive inbound
announcements may be observed because their private source address is allowed,
but only manually configured unicast services to private addresses can be
assumed. A fleet that depends on DHCP, reliable automatic printer/scanner
discovery, or a literal interface whitelist MUST obtain a newly approved
ruleset before Golden Master release. Build code must not fabricate that
approval.

---

## 11. SSH and administrative identity

### 11.1 Build inputs

The operator supplies two ignored files:

```text
secrets/localadmin_authorized_keys
secrets/localadmin_password_hash
```

`scripts/stage-admin-keys` accepts 1–20 unadorned ED25519 or security-key
ED25519 public keys, validates them with `ssh-keygen`, removes blank/full-line
comment records while preserving each public key's inline label, and writes an
ignored mode-0600 installer input. RSA and private keys are rejected.

`scripts/stage-localadmin-password` accepts exactly one newline-terminated
yescrypt (`$y$`) or SHA-512-crypt (`$6$`) record. The source must be a regular,
non-symlink file owned by the invoking build user with no group/other access.
Its parent must be owned by root/the build user and not group/other writable.
The script replaces exactly one token in `preseed.cfg.in`, rejects plaintext
password questions, and atomically writes ignored `preseed.cfg` with mode
0600. It never prints or passes the hash as a process argument.

These tasks remain separate by design: public-key normalization and secret
preseed rendering have different input classes, validators, and cleanup
requirements. `stage-build-inputs` in the Makefile composes them transactionally.

### 11.2 Installed policy

- only `localadmin` may use SSH;
- root SSH login denied;
- password and keyboard-interactive SSH denied;
- `AuthenticationMethods publickey` required;
- forwarding, agent forwarding, X11, tunnels, gateway ports, and user
  environment denied;
- verbose authentication logging, three attempts, 30-second grace time.

The shared console password remains necessary for local login and
password-authenticated `sudo`; it is never an SSH method. This shared-password
exception MUST be retired in favor of per-machine random escrow, centralized
identity, or another reviewed privileged-access design once SSH management is
operational.

### 11.3 Per-machine SSH identity

The installer late command removes copied host-key material and runs
`ssh-keygen -A` inside `/target`. Two installed machines MUST have different
host-key and machine-id hashes.

---

## 12. Debian Installer and partition safety

The rendered partial preseed answers locale, timezone, temporary hostname,
fixed admin username, the encrypted `localadmin` password, root-login policy,
mirror policy, and GPT default. It deliberately does not answer:

- target disk;
- partitioning method or recipe;
- removal of existing LVM/MD metadata;
- final partition selection;
- write-label or destructive confirmation;
- plaintext `passwd/user-password` or `passwd/user-password-again` fields;
- any root-password field.

Only `passwd/user-password-crypted` is seeded. This causes Debian Installer to
skip both interactive user-password prompts without exposing plaintext to
debconf. It does not hide the resulting hash from an operator who can inspect
the ISO/initrd or an installed machine's protected shadow database.

`partman/early_command` refuses installation when `/sys/firmware/efi` is
absent. Bootloader configuration is UEFI-only, so this is a second guard.

The installer flow is:

```text
UEFI boot
  -> graphical Debian Installer
  -> reviewed locale/time defaults
  -> injected crypt(3) hash creates localadmin without a password prompt
  -> operator selects disk and partitioning/encryption
  -> operator confirms destructive write
  -> Live filesystem copied to /target
  -> deterministic regular /etc/hostname and /etc/hosts materialized
  -> edbp-late-command validates localadmin and sudo
  -> public authorized_keys installed
  -> unique SSH host keys generated
  -> ssh/nftables/usbguard/OOBE enabled
  -> reboot
```

An installation that does not display disk selection and final destructive
confirmation is a release failure.

---

## 13. OOBE transaction model

### 13.1 Unit ordering

`edbp-oobe.service` is a TTY1 oneshot ordered before SDDM. An SDDM drop-in
requires it, preventing an empty graphical login chooser before a daily user
exists. The service skips:

- Live sessions containing `/run/live/medium`;
- completed systems containing `/var/lib/edbp/oobe-complete`.

### 13.2 Preconditions

OOBE refuses to proceed unless:

- it runs as root;
- `/etc/hostname` and `/etc/hosts` are regular files;
- `localadmin` exists;
- `localadmin` belongs to `sudo`;
- the sudoers policy exists.

### 13.3 Inputs and validation

- hostname: 1–63 lowercase letters, digits, and internal hyphens;
- daily username: lowercase POSIX-safe name, not already a user/group;
- password: 12–128 characters, not equal to username, entered twice;
- final summary confirmation required.

### 13.4 Commit and rollback

Before its first mutation, OOBE atomically publishes a root-owned mode-0700
rollback journal at `/var/lib/edbp/oobe-transaction`. The journal records the
previous hostname files and the validated account name. OOBE then creates a
private primary-group account, verifies that `scanner` is its only
supplementary group, updates hostname state, calls `sync`, and finally renames
an atomic completion marker. `scanner` is required by Debian's libsane udev
ACL; it does not grant system administration.

A normal error or signal rolls the journal back immediately. If power is lost
before marker commit, the next OOBE start verifies the journal's type,
ownership, mode, files, username, and expected home path before restoring the
hostname and deleting only that incomplete account. If power is lost after
marker commit, the completed account/hostname state is authoritative; a stale
root-only journal may remain but is never replayed.

After marker durability, service enablement is removed. The marker remains
authoritative because a dependency may activate a disabled unit.

---

## 14. Desktop and application policy

### 14.1 SDDM and sudo

`HideUsers=localadmin` is chooser cosmetics, not access control. Typed-name
login remains possible. `RememberLastUser=false` prevents leaking the most
recent account. Sudo requires the localadmin password; `NOPASSWD` is forbidden.

### 14.2 Brave

Managed policy enforces:

- home button and homepage: `https://home.mofa.sy/`;
- startup URL: `https://home.mofa.sy/`;
- new-tab URL: `https://home.mofa.sy/`;
- DuckDuckGo default search and suggestions.

The portal's internal DNS, TLS certificate, and enterprise CA chain are
deployment prerequisites. Verify effective policy at `brave://policy`.

### 14.3 LibreOffice

The administrator `.xcd` locks:

- Arabic UI locale;
- Tabbed Notebookbar for Writer, Calc, and Impress;
- DOCX default filter for text documents;
- XLSX default filter for spreadsheets;
- PPTX default filter for presentations.

Common Microsoft MIME types map to the corresponding LibreOffice desktop
files. OOXML default save improves interoperability but does not guarantee
lossless Microsoft Office round trips; representative documents MUST be tested.

### 14.4 KDE locale and keyboard

- Plasma/SDDM language: `en_US.UTF-8`;
- generated locales: `en_US.UTF-8`, `ar_SY.UTF-8`;
- layouts: `us,ara`;
- option: `grp:alt_shift_toggle`;
- KDE system configuration is marked immutable with `$i`.

Hook `040` materializes `/etc/default/locale -> ../locale.conf` after package
installation. It accepts an existing reviewed link or replaces only a regular
root-owned package-generated file; any other object aborts the build.

### 14.5 Desktop indexing

`/etc/xdg/baloofilerc` immutably disables Baloo content indexing. This removes
background database I/O and metadata retention on the 4 GiB sensitive
workstation baseline. Dolphin browsing remains available, but indexed
full-content search is intentionally not promised.

---

## 15. Hook execution order

`live-build` executes its packaged `config/hooks/normal/*.chroot` hooks before
the repository's `config/hooks/live/*.chroot` hooks, then runs its
`chroot_hacks` stage. In particular, normal hook 8050 removes image-baked SSH
host keys before EDBP hook `060` runs. Hook `060` therefore validates `sshd`
against an ephemeral ED25519 key under `/run`, removes that key on exit, and
never repopulates `/etc/ssh` in the image. `chroot_hacks` subsequently rebuilds
all initramfs images—capturing the Bluetooth modprobe policy—and removes the
Live image's `/etc/hosts`; the installer late command explicitly materializes
regular target hostname/hosts files and creates persistent, unique SSH host
keys in each installed target.

| Hook | Responsibility | Failure behavior |
|---|---|---|
| `010` | Remove broad USBGuard `plugdev` ACL, mask D-Bus unit/activation alias, set mode 0600 | Unexpected ACL/object or mask failure aborts |
| `020` | Remove Brave global-trust compatibility symlink | Unexpected target/object aborts |
| `030` | Enable nftables and USBGuard Isolated profile | Enable failure aborts |
| `040` | Permissions, sudo/JSON/XML/OOBE/systemd validation, LibreOffice link, locales, OOBE enablement | Any policy mismatch aborts |
| `050` | Keyring/nftables hash, nft/USBGuard syntax, forbidden packages/modules, unit/mask checks | Any drift aborts |
| `060` | SSH effective-policy verification with an ephemeral host key; enable SSH/network/print services; disable network SANE | Any required unit/policy failure aborts |
| `090` | APT/temp/cache/log cleanup | Filesystem error aborts |

Hooks use `set -eu` and are executable. They must fail closed instead of
silently repairing an unreviewed object.

Hook `040` invokes `systemd-analyze verify --man=no`: dependency, executable,
unit, and drop-in validation remain active, while only `Documentation=man:`
existence checks are skipped. The minimal image intentionally omits manpages,
so treating absent SDDM documentation as a service failure would be a false
positive and installing `man-db` solely to satisfy that check would be bloat.

---

## 16. Service policy

| Unit | Installed state | Rationale |
|---|---|---|
| `nftables.service` | enabled | Default Isolated network profile |
| `usbguard.service` | enabled installed system; condition-skipped Live | USB authorization enforcement |
| `ssh.service` | enabled | Key-only localadmin management |
| `edbp-oobe.service` | enabled until completion marker | First-boot identity |
| `sddm.service` | waits for OOBE | Prevent premature login UI |
| `NetworkManager.service` | enabled | Desktop LAN/Wi-Fi management |
| `cups.service`, `cups.socket` | enabled | Printing |
| `cups-browsed.service` | enabled | Accepted Plug-and-Play/network discovery cost |
| `avahi-daemon.service` | enabled | mDNS/IPP discovery |
| `saned.socket`, `saned@.service` | disabled | Local SANE does not require a network scanner server |
| `usbguard-dbus.service` and D-Bus alias | masked plus deny-activation drop-in | CLI talks directly to daemon; survives package-level enablement drift and blocks the broader Polkit surface |

The enabled discovery daemons are an accepted footprint and LAN attack-surface
cost. CUPS/Avahi behavior MUST be tested on the production VLAN.

---

## 17. Build automation

### 17.1 Required build-host packages

On a clean Debian 13 amd64 builder:

```bash
sudo apt update
sudo apt install --yes \
    live-build debootstrap squashfs-tools xorriso \
    grub-efi-amd64-bin shim-signed mtools dosfstools \
    make git jq openssh-client sudo shellcheck \
    debconf-utils python3 ca-certificates whois
```

Build as an unprivileged dedicated user with narrowly controlled sudo access
to `lb build`/`lb clean`. Do not build inside a developer's daily workstation
profile for a signed release.

### 17.2 Administrative build inputs

```bash
install -d -m 0700 secrets
ssh-keygen -t ed25519 -a 100 -f secrets/edbp_admin -C edbp-admin
install -m 0600 secrets/edbp_admin.pub secrets/localadmin_authorized_keys

# Prompts on the terminal; plaintext is not placed in argv or shell history.
( umask 077; mkpasswd --method=yescrypt > secrets/localadmin_password_hash )
chmod 0600 secrets/localadmin_password_hash
```

The private file `secrets/edbp_admin` must be moved to approved key custody and
must never accompany the ISO. The password itself MUST be generated and stored
through the approved credential vault; it MUST NOT appear in a command-line
argument, ticket, Git commit, build log, or technician document.

The shared password SHOULD have at least 20 randomly generated characters.
Human-memorable organizational names, seasons, keyboard walks, and predictable
suffixes are prohibited. A salted password hash slows guessing but does not
prevent offline guessing after ISO extraction.

### 17.3 Injection and cleanup transaction

`make config` first runs the clean-tree verifier, stages the normalized public
keys, and renders the encrypted-password line from `preseed.cfg.in`. The real
hash is read from the source file inside the renderer; it is never interpolated
by Make or placed in process arguments. If either staging operation fails, both
outputs are deleted.

The generated files are:

```text
config/includes.installer/localadmin_authorized_keys
config/includes.installer/preseed.cfg
edbp-2.2.0-amd64.build-inputs.json
```

The first two exist only because `live-build` must read them while assembling
the installer initrd. `make build` and the production `make all` entry point
install EXIT/signal traps that remove both secret-bearing files after success,
failure, or interrupt. `make config` intentionally leaves them staged for a
later build and therefore prints a warning; the operator MUST follow it with
`make build` or `make clean`.

The third file is a non-secret provenance artifact created at staging time. It
contains only SHA-256 fingerprints of the exact normalized public keys,
injected crypt string, template, and rendered preseed. Capturing these values
before the long build closes the race where a source secret could be rotated
mid-build and later be misidentified as the value embedded in the ISO.

The source files under `secrets/` are not deleted automatically. They are
external controlled inputs and remain under the build-controller custody
policy. Neither provenance JSON file contains the password hash value.

### 17.4 Targets

| Target | Behavior |
|---|---|
| `make verify` | Require and validate both real inputs; render preseed only in a temporary directory; run all static/security checks |
| `make verify-test` | Permit a synthetic non-login hash only for temporary static validation when the real hash file is absent; cannot satisfy build dependencies |
| `make stage-build-inputs` | Transactionally stage public keys and the rendered secret-bearing preseed |
| `make config` | Verify, stage both inputs, run repository `auto/config`; leaves staged files for build |
| `make build` | Configure, run privileged `lb build` (`sudo` for the normal unprivileged builder), retain `build.log`, scrub staged inputs on every exit path |
| `make all` | Trap cleanup, build, create checksums/manifest, and verify checksums |
| `make verify-checksums` | Verify existing `SHA256SUMS` and manifest paths |
| `make scrub-build-inputs` | Delete only generated preseed and staged authorized keys |
| `make clean` | Purge live-build state and generated artifacts/staged inputs; preserve source secrets |

`make config` and `make build` force a build-safe `umask 022`. Secret staging
scripts independently enforce `umask 077`, and the password-generation example
uses a subshell so a restrictive umask cannot leak into `live-build`. This keeps
APT's `_apt` sandbox able to traverse its cache instead of falling back to an
unsandboxed root download.

Production build:

```bash
git status --short
git check-ignore --quiet secrets/localadmin_password_hash
make clean
make verify
make all
```

Expected artifacts:

```text
edbp-2.2.0-amd64.hybrid.iso
edbp-2.2.0-amd64.packages
edbp-2.2.0-amd64.build-inputs.json
edbp-2.2.0-amd64.manifest.json
SHA256SUMS
build.log
```

The JSON manifest records version, architecture, Git commit,
`SOURCE_DATE_EPOCH` and its UTC rendering, manifest-creation time, SHA-256
fingerprints for the normalized public-key payload, injected password hash,
preseed template, rendered preseed, plus ISO, package-manifest, and
build-input-record hashes. `make verify-checksums` recomputes every recorded
artifact identity except the informational manifest-creation time.

---

## 18. Static and forensic verification

### 18.1 Repository checks

```bash
git status --short
git fsck --full
git diff --check origin/main...HEAD
make verify
git grep -nE 'BEGIN (OPENSSH|RSA|EC|DSA|PRIVATE) PRIVATE KEY' -- .
git check-ignore --quiet secrets/localadmin_password_hash
test "$(stat -c '%a' secrets/localadmin_password_hash)" = 600
```

`make verify` intentionally refuses a dirty source tree. During development
only, `EDBP_ALLOW_DIRTY=1` may be supplied; such a build cannot be released.
If the real hash file is intentionally absent during source-only CI,
`make verify-test` renders a synthetic non-login hash solely under `mktemp`.
That fallback is not reachable from `make config`, `make build`, or `make all`.

### 18.2 ISO structure and UEFI

```bash
sha256sum --check --strict SHA256SUMS
xorriso -indev edbp-2.2.0-amd64.hybrid.iso \
    -report_el_torito as_mkisofs
xorriso -indev edbp-2.2.0-amd64.hybrid.iso \
    -find /EFI -type f -exec lsdl
```

Acceptance:

- EFI boot image present;
- no legacy isolinux/BIOS boot catalog entry;
- graphical installer and Live entries present;
- embedded installer initrd contains `/preseed.cfg`, `/edbp-late-command`, and
  `/localadmin_authorized_keys`;
- `/preseed.cfg` contains exactly one `$y$` or `$6$`
  `passwd/user-password-crypted` record, contains no plaintext-password
  record, and contains no unresolved template token;
- no SSH private key exists anywhere in the ISO.

### 18.3 UEFI VM boot

Example non-Secure-Boot test:

```bash
cp /usr/share/OVMF/OVMF_VARS_4M.fd /tmp/edbp-vars.fd
qemu-system-x86_64 \
    -enable-kvm \
    -machine q35 \
    -cpu host \
    -smp 4 \
    -m 4096 \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
    -drive if=pflash,format=raw,file=/tmp/edbp-vars.fd \
    -drive if=virtio,format=qcow2,file=/var/lib/edbp-test/disk01.qcow2 \
    -cdrom edbp-2.2.0-amd64.hybrid.iso \
    -boot d
```

Repeat with the distribution's Secure-Boot OVMF code and enrolled Microsoft/
Debian keys when Secure Boot is an acceptance requirement.

### 18.4 Installer acceptance

For NVMe-emulated and SATA-emulated disks, verify:

1. no BIOS boot path;
2. installer English locale and Damascus timezone defaults;
3. no localadmin or root password prompt appears;
4. disk and recipe selection remain interactive;
5. final destructive confirmation appears;
6. GPT and EFI System Partition are created for guided UEFI installation;
7. installed system boots without ISO;
8. the controlled shared password authenticates `localadmin` locally and
   satisfies password-required `sudo`;
9. OOBE blocks SDDM until completion.

### 18.5 Installed-system checks

```bash
systemctl is-enabled nftables usbguard ssh edbp-oobe
systemctl --failed
sudo nft --check --file /etc/nftables.conf
sudo nft list ruleset
sudo usbguard list-rules
sudo usbguard list-devices
sudo sshd -T -C user=localadmin,host=localhost,addr=127.0.0.1 \
    | grep -E '^(permitrootlogin|passwordauthentication|authenticationmethods|allowusers) '
sudo visudo -cf /etc/sudoers.d/localadmin
id localadmin
getent passwd DAILY_USER
id DAILY_USER
test -e /var/lib/edbp/oobe-complete
```

Daily-user acceptance: no `sudo`, `lpadmin`, or `plugdev` membership;
`scanner` is the only supplementary group.

### 18.6 Identity uniqueness across two installs

Run on each installed VM and compare:

```bash
sha256sum /etc/machine-id
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
stat -c '%a %U:%G %n' /home/localadmin/.ssh \
    /home/localadmin/.ssh/authorized_keys
```

Machine-id and SSH host fingerprints MUST differ. Authorized-key content may be
the same approved fleet management key.

### 18.7 Application acceptance

- `brave://policy` shows all EDBP policies as mandatory with no errors;
- `https://home.mofa.sy/` resolves and presents a trusted certificate;
- DuckDuckGo is the locked search provider;
- a new LibreOffice profile opens Arabic Tabbed UI;
- new Writer/Calc/Impress documents default to DOCX/XLSX/PPTX;
- representative Arabic/English Office files survive round-trip testing;
- each approved printer/scanner model prints/scans over its production path;
- HID works, storage blocks, mixed HID+storage blocks, and localadmin temporary
  authorization behaves as documented.

---

## 19. Release gates

### P0 — mandatory before any workstation deployment

- clean committed source and reviewed PR;
- real ED25519 admin public-key input, private key in approved custody;
- real high-entropy localadmin hash input owned/mode-0600 on the isolated build
  controller; password held in the approved vault;
- documented shared-password expiry, fleet rotation, and break-glass process;
- successful full `make all` on Debian 13 builder;
- checksum and provenance artifacts retained;
- two UEFI install/boot/OOBE passes;
- disk-confirmation test on NVMe and SATA;
- unique machine-id and SSH host keys;
- no failed systemd units;
- nftables DHCP/multicast/broadcast/interface behavior accepted or corrected by cybersecurity;
- SSH key login succeeds and all SSH password methods fail;
- USB policy tested against actual keyboards, mice, hubs, printers, and scanners.
- explicit LUKS requirement/recovery-key decision for the sensitive-workstation role.

### P1 — mandatory before fleet expansion

- controlled APT snapshot/mirror and rollback policy;
- printer/scanner VID/PID and vendor-package inventory;
- enterprise CA and internal DNS/NTP validation;
- signed release tag and immutable Git-commit-to-ISO mapping;
- staged pilot, telemetry, incident logging, and recovery procedure.

### P2 — recommended hardening backlog

- formal AppArmor profile coverage report;
- PAM password-quality/lockout policy with help-desk recovery testing;
- auditd or equivalent privileged-session audit policy;
- desktop-compatible sysctl baseline;
- automated UEFI/Secure-Boot CI and SBOM generation.

---

## 20. Known constraints and rejected shortcuts

1. **Not a literal nftables interface whitelist.** The approved rules use
   private address ranges. Documentation cannot turn that into interface
   filtering.
2. **DHCP and active LAN discovery are blocked in Isolated mode.** Broadcast
   and multicast destinations are outside the approved ranges; passive inbound
   announcements may still appear. Reliable operation requires cyber approval,
   static/manual configuration, or a revised ruleset.
3. **Generic USB classes do not cover all peripherals.** Hubs and vendor class
   scanners require inventory-specific policy.
4. **`printer-driver-all` is not universal.** Proprietary HP/Epson support is
   model-specific.
5. **OOXML defaults are not perfect compatibility.** Round-trip testing is
   mandatory.
6. **Stopping nftables removes all filtering.** It is a temporary exception,
   not a persistent Connected profile.
7. **Terminal history is not globally disabled.** Removing administrative
   history is anti-forensic. Any standard-user privacy policy must be designed
   separately without suppressing privileged auditability.
8. **Rolling repositories are not bit-reproducible.** A controlled mirror is
   required for long-term fleet reproducibility.
9. **Dependency fonts are not deleted.** Plasma, LibreOffice, browsers, and
   document fallback depend on additional fonts pulled by Debian. Deleting all
   non-selected font packages would break rendering and package integrity; a
   fontconfig policy requires a separate typography acceptance test.
10. **The approved branding asset is immutable build input.** KDE defaults to
    the supplied `EDBP Green` 1920x1080 JPEG through `/etc/xdg/plasmarc` and a
    standard Plasma wallpaper package. The source SHA-256 is
    `7c50dbc995c667b7fba7014801598dca23dd281efa80e5f8e4c89e10bf49f84b`.
    The setting is a default for new profiles, not a lock; users may select a
    different wallpaper. Displays above 1920x1080 will upscale this asset.
11. **A shared fleet password has fleet-wide blast radius.** Its crypt(3) hash
    is recoverable from every distributed ISO and installed shadow database.
    Compromise or offline cracking of one value affects every machine built
    from that input. Build-time injection prevents Git/log disclosure; it does
    not create per-device uniqueness or protect a weak password. This exception
    is acceptable only as a dated migration control, not a steady-state
    privileged-access architecture.

---

## 21. Authoritative upstream references

- [Debian Live Manual: customizing Debian Installer](https://live-team.pages.debian.net/live-manual/html/live-manual/customizing-installer.en.html)
- [Debian 13 Installer Manual: loading preseed](https://www.debian.org/releases/trixie/amd64/apbs02.en.html)
- [Debian 13 Installer Manual: preseed contents](https://www.debian.org/releases/trixie/amd64/apbs04.en.html)
- [Debian Trixie `live-build` manpages](https://manpages.debian.org/trixie/live-build/)
- [USBGuard rule language](https://manpages.debian.org/trixie/usbguard/usbguard-rules.conf.5)
- [Debian nftables package source and service behavior](https://sources.debian.org/src/nftables/)
- [Brave enterprise Group Policy guidance](https://support.brave.com/hc/en-us/articles/360039248271-Group-Policy)
- [Chromium enterprise policy catalogue used by Brave](https://chromeenterprise.google/policies/)
- [LibreOffice ToolbarMode schema and data](https://github.com/LibreOffice/core/tree/master/officecfg/registry)
- [KDE Baloo source and autostart condition](https://invent.kde.org/frameworks/baloo)

---

## 22. Change control

Any change to the following is security-significant and requires review plus a
new artifact manifest:

- package list or repository/pinning/keyring;
- `auto/config` boot or installer options;
- nftables bytes/hash;
- USBGuard policy or IPC ACL;
- Bluetooth module denial;
- SSH policy or injected public keys;
- password-hash algorithm, source, rotation, renderer, or staged output;
- Preseed identity/partitioning questions or template token;
- installer late command;
- OOBE transaction/marker behavior;
- enabled daemon set;
- application managed policy.

The repository history, signed release tag, `.packages` manifest,
`SHA256SUMS`, and JSON manifest together form the minimum release provenance
record.
