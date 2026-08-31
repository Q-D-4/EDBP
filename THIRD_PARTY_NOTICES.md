# EDBP third-party and separately licensed materials

This file records material in the EDBP source tree that is not solely EDBP-original work under the repository's default `GPL-3.0-or-later` grant.

The presence of a component in this repository or in an EDBP-built ISO does not change that component's upstream copyright or license.

## USBGuard-derived configuration

### `config/includes.chroot_after_packages/etc/usbguard/usbguard-daemon.conf`

This file is adapted from the USBGuard 1.1.3 daemon configuration template.

- Upstream project: USBGuard
- Reviewed upstream version: 1.1.3
- Upstream source: https://github.com/USBGuard/usbguard/blob/usbguard-1.1.3/usbguard-daemon.conf.in
- Debian copyright information: https://sources.debian.org/src/usbguard/1.1.3%2Bds-3/debian/copyright/
- Applicable upstream license: `GPL-2.0-or-later`

EDBP-specific changes and comments do not remove the upstream attribution or license applicable to the adapted material.

### `config/includes.chroot_after_packages/etc/usbguard/IPCAccessControl.d/:sudo`

This file contains the three-line USBGuard ACL example used for a restricted IPC policy.

- Upstream project: USBGuard
- Reviewed upstream version: 1.1.3
- Upstream documentation: https://github.com/USBGuard/usbguard/blob/usbguard-1.1.3/doc/man/usbguard-daemon.conf.5.adoc
- Applicable upstream license: `GPL-2.0-or-later`

The exact ACL fragment is highly functional and may be below the copyright threshold in some jurisdictions; EDBP nevertheless preserves upstream attribution and treats it conservatively as upstream-derived.

## Debian base-files and GNU Bash test fixture

### `tests/test-bash-session-history-policy`

The test harness is EDBP-authored, but its fixture reproduces short portions of Debian's system profile/bash initialization structure used to verify compatibility.

- Debian base-files source: https://sources.debian.org/src/base-files/13.8%2Bdeb13u6/share/profile/
- GNU Bash Debian configuration: https://sources.debian.org/src/bash/5.2.37-2/debian/etc.bash.bashrc/
- base-files license: `GPL-2.0-or-later`
- Bash packaging/license applicable to the reproduced fixture: `GPL-3.0-or-later`

The combined EDBP test file is distributed under `GPL-3.0-or-later`, while preserving attribution to the upstream fixture sources.

## Debian live-installer test fixture

### `tests/test-finish-install-reboot`

The EDBP test harness contains a verbatim fixture of Debian live-installer 58's very short `98exit-installer` hook for compatibility testing.

- Upstream project: Debian live-installer
- Reviewed upstream version: 58
- Upstream file: https://sources.debian.org/src/live-installer/58/finish-install.d/98exit-installer/
- Debian copyright information: https://sources.debian.org/src/live-installer/58/debian/copyright/
- Applicable upstream license: `GPL-2.0-or-later`

The combined EDBP test file may be distributed under `GPL-3.0-or-later`; the embedded upstream fixture retains its provenance and applicable upstream rights.

## Organization-provided security policy

### `config/includes.chroot_after_packages/etc/nftables.conf`

This firewall policy was supplied by the cybersecurity team of the organization that deploys EDBP. It is not claimed as original copyright of Osama Haddad (Q-D-4) and is **not covered by the default EDBP GPL grant**.

The organization is aware of and has authorized its publication/distribution as part of EDBP. No separate public open-source license has been granted for this file by this repository.

## Organization-owned wallpaper

### `config/includes.chroot_after_packages/usr/share/wallpapers/EDBP/contents/images/1920x1080.jpg`
### `config/includes.chroot_after_packages/usr/share/wallpapers/EDBP/metadata.json`

The wallpaper was created by media staff of the organization that deploys EDBP. Its metadata declares `"License": "Proprietary"`.

The organization is aware of and has authorized publication/distribution of the artwork as part of EDBP. The artwork and its accompanying proprietary-license metadata are **not covered by the default EDBP GPL grant**.

## Brave signing material

The following files contain Brave vendor signing/keyring material and are not EDBP-original copyright:

- `config/archives/brave-browser.key`
- `config/includes.chroot_after_packages/usr/share/keyrings/brave-browser-archive-keyring.gpg`

Official vendor signing-key information: https://brave.com/signing-keys/

These files are **not covered by the default EDBP GPL grant**. The Brave name and related marks remain the property of their respective owners.

## Element signing material

The following files contain Element vendor signing/keyring material and are not EDBP-original copyright:

- `config/archives/element-io.key`
- `config/includes.chroot_after_packages/usr/share/keyrings/element-io-archive-keyring.gpg`

Official vendor repository/download information: https://element.io/en/download

These files are **not covered by the default EDBP GPL grant**. The Element name and related marks remain the property of their respective owners.

## Generated ISO contents

EDBP builds and distributes a Debian-based ISO containing software from Debian and third-party repositories. Every packaged component retains its own copyright and license. The EDBP license applies only to EDBP-covered source/configuration and does not relicense Debian, KDE, Brave, Element, USBGuard, BusyBox, systemd, OpenSSH, LibreOffice, or other packaged software.

Build-time modification of upstream configuration files inside the generated ISO does not convert those upstream files into EDBP-owned works; their upstream notices and license obligations remain applicable.
