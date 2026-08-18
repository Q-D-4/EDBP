# EDBP Layer 02 — Repositories, packages, USBGuard, and nftables

This document records the engineering decisions behind the layer-02 files. It
is intentionally explicit so that an operator does not have to infer behavior
from `live-build` file suffixes or APT metapackages.

## Third-party APT trust model

| Repository | Build source | Installed-system source | Eligible packages |
|---|---|---|---|
| Brave | `brave-browser.list.chroot` | `brave-browser-release.list.binary` | `brave-browser`, `brave-keyring` |
| Element | `element-io.list.chroot` | `element-io.list.binary` | `element-desktop`, `element-io-archive-keyring` |

`live-build` removes `.list.chroot` files from the final filesystem. The
matching `.list.binary` files are therefore mandatory: without them, connected
workstations would install Brave/Element but would not receive updates.

Build keys use the short-lived path created by `live-build` under
`/etc/apt/trusted.gpg.d/`, with `Signed-By` still restricting each source to its
own key. Runtime sources use repository-scoped keyrings under
`/usr/share/keyrings/`; no third-party key is intended to remain globally
trusted.

The `.pref` files make every package from each external origin ineligible with
priority `-1`, then allow only the reviewed package names at priority `500`.
This deliberately excludes `brave-origin`, `element-nightly`, and `element-web`.

Verified key material:

| Repository | Primary fingerprint(s) | SHA-256 of keyring |
|---|---|---|
| Brave | `DBF1A116C220B8C7164F98230686B78420038257`; `47D32A74E9A9E013A4B4926C68D513D36A73CD96`; `B2A3DCA350E67256740DF904DE4EC67BE4B0DCA0` | `c85e85aa3d1783ffaa649ee8dbbc22af7f87192d304602d37e3018226b394788` |
| Element | `12D4CD600C2240A9F4A82071D7B0B66941D01538` (signing subkey `75741890063E5E9A46135D01C2850B265AC085BD`) | `c2cb0c6bf269c56158e3c0ae8185cbeee168db5071bef659b97b1a775ebc1955` |

`brave-browser` has a hard dependency on `brave-keyring`. During installation,
its maintainer script creates a compatibility symlink in the global APT trust
directory because only the differently named build source exists at that
stage. The `020-remove-brave-global-trust.hook.chroot` hook verifies that exact
symlink and removes it; an unexpected object makes the build fail. The final
source is deliberately named `brave-browser-release.list`, which the vendor
maintainer script recognizes, so later keyring upgrades do not recreate global
trust.

## Package-list dependency map

### `live-runtime.list.chroot`

- `live-build` generates a transient `live.list.chroot` containing
  `live-boot`, `live-config`, `live-config-systemd`, and `systemd-sysv`.
- `user-setup` is an operational recommendation of `live-config` and is needed
  to create/configure the ephemeral Live user when APT recommendations are
  disabled.
- `locales` and `keyboard-configuration` are explicit because the image
  declares English/Arabic locale and keyboard boot parameters. The parameters
  alone do not install the programs/data that apply them.

### `desktop.list.chroot`

- `plasma-desktop` pulls the Plasma workspace, KWin Wayland, KIO, Polkit agent,
  UDisks, and the core Qt/QML runtime.
- `sddm` hard-depends on the `xserver-xorg` provider. That metapackage pulls the
  Debian X.Org input/video driver set; this is not optional without replacing
  SDDM or rebuilding its package.
- Plasma's operational recommendations (`kscreen`, `plasma-nm`, `plasma-pa`,
  `powerdevil`, `systemsettings`, portals, and KIO extras) are named explicitly.
  `task-kde-desktop`, `kde-standard`, games, PIM, Discover, Welcome, and
  BlueDevil are not installed.
- `plasma-nm` depends on NetworkManager and Qt WebEngine. It is a significant
  footprint cost, accepted here to provide a usable KDE network UI.
- `wpasupplicant` and `wireless-regdb` are explicit because NetworkManager only
  recommends them. Without them the desktop would expose Wi-Fi controls but
  could not establish normal WPA/WPA2/WPA3 connections. Remove both only after
  an explicit Ethernet-only policy decision.
- Audio uses `pipewire`, `pipewire-pulse`, `pipewire-alsa`, and `wireplumber`
  directly. The `pipewire-audio` metapackage is excluded because it hard-pulls
  `libspa-0.2-bluetooth` on Debian 13.
- Ark's common command backends (`7zip`, `bzip2`, `unzip`, and `zip`) are
  explicit. Installing Ark alone while recommendations are disabled would
  expose an archive UI with incomplete create/extract coverage.

### `productivity.list.chroot`

- Writer, Calc, and Impress pull `libreoffice-core`; Impress also pulls Draw.
  `libreoffice-math` is explicit so formulas embedded in Office documents can
  be edited even though Writer declares it only as a recommendation.
- `libreoffice-kf6` pulls Qt 6 integration and KIO; the Plasma integration and
  Breeze icon style are explicit because APT recommendations are disabled.
- `libreoffice-l10n-ar` pulls locale data. `hunspell-ar` and `mythes-ar` add
  Arabic spell checking and thesaurus support.
- `fonts-noto-core`, Liberation (including Sans Narrow), Croscore, Carlito,
  Caladea, and Scheherazade
  cover Arabic/Latin rendering and Microsoft-compatible metrics.
- `fonts-noto-extra` is intentionally excluded: it is about 326 MiB installed
  and is not needed for the stated English/Arabic scope.
- Debian 13 does not publish `libreoffice-help-ar` or `hyphen-ar`; neither name
  may be placed in a Trixie package list.

### `hardware-printers.list.chroot`

- `cups` pulls the print daemon, filters, Ghostscript, and core drivers.
- `cups-browsed`, Avahi, `ipp-usb`, and `sane-airscan` provide network/driverless
  discovery. They add daemon and LAN attack surface; later service hardening
  must restrict discovery to trusted interfaces.
- `cups-pk-helper`, `print-manager`, and `system-config-printer-udev` provide
  standard-user configuration and USB plug-and-play behavior.
- `printer-driver-all` is only an eight-KiB metapackage whose drivers are
  **Recommends**, not Depends. Because EDBP disables APT recommendations, its
  complete Trixie driver set is expanded explicitly in the file.
- `hplip` pulls the HPAIO SANE backend and HP CUPS driver; `hplip-gui` adds the
  requested Qt/Python management UI.
- `printer-driver-escpr` is Debian's open Epson ESC/P-R driver. There is no
  universal proprietary Epson Debian repository/package; any vendor driver must
  be added only after the exact printer model IDs and vendor package signatures
  are inventoried.

### `security-core.list.chroot`

- `usbguard` supplies the daemon, CLI, seccomp-aware service unit, and IPC
  library.
- `nftables` supplies the ruleset loader and `nftables.service`.
- `openssh-server` pulls the SSH client/SFTP server and PAM dependencies.
- `sudo` supplies local administrative elevation; `ca-certificates` is required
  for HTTPS APT repositories.

### `applications.list.chroot`

This additional list is intentional. Putting externally owned desktop apps in
`productivity.list.chroot` would hide their separate trust/update boundary.

- `brave-browser` pulls `brave-keyring` and Chromium runtime libraries.
- `element-desktop` is an Electron application with a large self-contained
  runtime.
- `element-io-archive-keyring` permits signed key rotation on connected hosts.
- `keepassxc-minimal` removes networking, SSH-agent, browser-integration, and
  Secret Service features. Font Awesome is explicit because its UI recommends
  that icon font. Use `keepassxc-full` only if one of those features becomes an
  approved requirement.

## Why APT recommendations are disabled

With `--apt-recommends true`, `plasma-desktop` reintroduces `bluedevil`, Plasma
Discover, Welcome, documentation, and other non-required packages. Conversely,
`printer-driver-all` becomes ineffective when recommendations are disabled
unless its driver set is explicitly listed. EDBP therefore uses
`--apt-recommends false` and promotes every accepted operational recommendation
to a direct package entry.

An isolated Trixie APT simulation on 2026-08-18 resolved all 93 unique direct
package entries and their dependencies successfully: 1,267 packages from an
empty dpkg status database, with an aggregate `Installed-Size` of approximately
3.59 GiB before SquashFS compression. The simulation used
`APT::Install-Recommends=false`, the repository-scoped keys, and the committed
APT pins. These figures must be regenerated whenever a direct package entry or
repository snapshot changes; stale counts must not enter a release manifest.

The largest requested costs remain Element, Brave, and Qt WebEngine. This image
is minimal only relative to the accepted application/peripheral requirements;
calling the result a generally minimal desktop would be inaccurate.

The simulation confirmed that `bluez`, `bluedevil`,
`libspa-0.2-bluetooth`, Plasma Discover, Element Nightly, and Brave Origin are
not selected. `libbluetooth3` remains because NetworkManager hard-depends on its
ABI; it is a library, not the BlueZ daemon, and the Bluetooth kernel modules are
still denied.

## USBGuard policy

The single allow rule uses USBGuard 1.1.3's `match-all` set operator. A device
is permitted only when its **complete** interface set is a subset of HID (`03`),
Still Imaging (`06`), and Printer (`07`). Therefore HID+Mass-Storage and
Printer+Mass-Storage composite devices do not pass.

Everything else receives the implicit `block` target. Root keeps full IPC
access. The `:sudo` ACL grants only device modification/listening plus policy
listing, enough for `usbguard allow-device`; it does not grant arbitrary generic
policy edits.

Debian's package post-install script creates an unwanted `:plugdev` ACL and
enables the optional D-Bus bridge. The
`010-harden-usbguard-package-defaults.hook.chroot` hook removes that ACL,
disables the bridge, and enforces mode `0600` on policy/IPC files.

USBGuard must not enforce this class policy inside a USB-booted Live session:
the class-08 device being blocked is the medium that supplies the running
SquashFS root. The `10-skip-live-session.conf` systemd drop-in uses Debian
live-boot's `/run/live/medium` mount as a negative start condition. USBGuard is
therefore skipped only in Live mode and starts normally on the installed OS.

Operational limitation: many real USB scanners and some multifunction printers
use vendor-specific (`ff`) interfaces rather than class `06`/`07`. Permitting all
`ff` devices would destroy the whitelist. Those models require reviewed,
device-specific USBGuard rules after a hardware inventory.

## Approved nftables file

The installed `/etc/nftables.conf` is byte-for-byte identical to the supplied
cybersecurity-approved file:

`04f5ff6be56fe60acd6b7ee031832b41e8671ae09c42ba141b91da04f0e0114a`

No rule was silently changed. Engineering observations that still require an
explicit owner decision:

- The file has no explicit DHCP client broadcast exception (`udp 68 -> 67`,
  destination `255.255.255.255`). DHCP clients whose traffic traverses the
  output hook can be blocked before they receive a LAN address.
- New IPv6 connections are denied; only loopback and established/related state
  can pass without an IPv6 allow rule.
- Any host in any RFC1918 range is allowed to initiate any input protocol. This
  is LAN isolation, not host-level service minimization.

On Debian 13, stopping `nftables.service` runs `nft flush ruleset`, so
`systemctl stop nftables` really does remove the active rules until the next
enabled start/reboot. A permanently connected profile would require
`systemctl disable --now nftables`; that broad profile switch should remain an
administrator-only action. Debian ships this service disabled on a fresh
installation, so `030-enable-isolated-security-profile.hook.chroot` explicitly
enables both nftables and USBGuard for EDBP's default Isolated profile.
