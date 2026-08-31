# EDBP licensing scope

Copyright © 2026 Osama Haddad (Q-D-4).

Unless a file contains a different license notice or is listed as excluded below, EDBP-original software and copyrightable configuration in this repository is licensed under the GNU General Public License, version 3 or any later version (`GPL-3.0-or-later`).

The complete GNU GPL version 3 license text is provided in the repository root `LICENSE` file.

This default grant does **not** override copyright or licensing terms that apply to third-party, upstream-derived, or organization-owned material. Those materials are documented in `THIRD_PARTY_NOTICES.md` and, where applicable, by per-file SPDX notices.

In particular, the default EDBP GPL grant does not cover:

- `config/includes.chroot_after_packages/etc/nftables.conf` — organization-provided security policy.
- `config/includes.chroot_after_packages/usr/share/wallpapers/EDBP/contents/images/1920x1080.jpg` — organization-owned proprietary artwork.
- `config/includes.chroot_after_packages/usr/share/wallpapers/EDBP/metadata.json` — metadata accompanying the proprietary artwork.
- Brave and Element signing/keyring material identified in `THIRD_PARTY_NOTICES.md`.

The following files contain upstream-derived material and retain the upstream attribution and licensing described in `THIRD_PARTY_NOTICES.md`:

- `config/includes.chroot_after_packages/etc/usbguard/usbguard-daemon.conf`
- `config/includes.chroot_after_packages/etc/usbguard/IPCAccessControl.d/:sudo`
- `tests/test-bash-session-history-policy`
- `tests/test-finish-install-reboot`

## Documentation

The following EDBP-original documentation is licensed separately under the Creative Commons Attribution-ShareAlike 4.0 International license (`CC-BY-SA-4.0`):

- `README.md`
- `EDBP-v2.2.0-SPECIFICATION.md`

Copyright © 2026 Osama Haddad (Q-D-4). The complete documentation license text is provided at `LICENSES/CC-BY-SA-4.0.txt`.

The documentation license does not change the licenses of code snippets, third-party material, vendor names, trademarks, or separately licensed files quoted or referenced by the documentation.

Where an SPDX identifier and this scope statement differ, the more specific per-file notice controls for that file.
