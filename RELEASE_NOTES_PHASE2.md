# EDBP — Phase 2 Candidate Release Notes

**Status:** Candidate implementation and single-device runtime pilot — **not a production release**

**Platform:** Debian 13 (Trixie), amd64, UEFI, KDE Plasma 6

**Version file at time of pilot:** `2.2.0`

**Evidence date:** 2026-10-12

> This note describes the observed Phase 2 candidate. It does not assign a new release number, mark a Golden Master, certify general hardware compatibility, or authorize publication of the laboratory ISO.

## Improvements

### Enterprise Flatpak delivery

- Explicit Flatpak tooling and reviewed application catalog.
- Reviewed Flathub trust material and isolated, fresh acquisition on each image build.
- Validation of the acquired Flatpak/OSTree content and an offline-ready image payload.
- System-wide ONLYOFFICE Desktop Editors and RustDesk, with Flatseal installed only for the administrative user.
- Validation gates that reject stale or incomplete build inputs rather than silently accepting leftovers from failed builds.

### Reliable installer-to-first-boot transition

- Changed installer `late_command` behavior to **verify staged Flatpak inputs**, not perform administrative Flatpak provisioning while the target D-Bus/session environment is unavailable.
- Provision Flatseal on **first boot** using `edbp-flatseal-provision.service` before the normal OOBE and SDDM startup sequence.
- Fail-closed checks confirm expected Flatpak refs and installation scope; diagnostic journal output supports post-install review.
- Preserve the restricted daily-user privilege model.

### Validation and recovery

- Added focused regression coverage for the First-Boot service and provisioning integration, including unit/policy verification.
- A physical-workstation pilot successfully booted, installed, completed First-Boot/OOBE and launched the tested graphical applications.

## Observed runtime results

| Check | Observation |
| --- | --- |
| ISO build | Completed successfully |
| ISO integrity | SHA-256 verified for the laboratory candidate |
| UEFI | ISO contains an EFI El Torito boot image; physical UEFI boot succeeded |
| Debian Installer | Installation completed on one physical workstation |
| First-Boot Flatseal service | `Result=success`; `ExecMainStatus=0` |
| Provisioning helper | Reported `PASS: 11 system refs and admin-only Flatseal pinned/verified` |
| Flatseal scope | Present for `edbpadmin`; absent from system and tested regular-user installations |
| Flatseal desktop UI | Opened under the administrative account |
| OOBE | Created a non-privileged daily user; service finished successfully |
| Second reboot | System and installed Flatpak applications remained available |
| ONLYOFFICE | Application GUI opened and behaved normally |
| RustDesk | Application GUI opened and behaved normally |
| Restrictive network baseline | Applications launched without public Internet access |

## Not yet demonstrated

- An independent second install with a distinct hardware or VM environment under the full specification acceptance procedure.
- Complete printer, scanner, USB dock and peripheral allowlist testing.
- Full remote-control functionality of RustDesk; opening its GUI offline does not test external connectivity.
- Security reviewer sign-off on the baseline `nftables` rules and any site-specific exceptions.
- A fully clean, committed **production release build** with approved credentials, full provenance and independently retained release artifacts.

## Publishing boundary

**Publish reviewed source and documentation only.** The pilot ISO was built with laboratory administrator credentials: do **not** attach, upload or distribute that ISO. Do not publish any administrator password hashes, staged preseed files, SSH keys, cached OSTree builds, `.build/`, `chroot/` or generated package archives.

For the raw validation evidence and exact laboratory ISO hash, see [Phase 2 runtime acceptance](docs/PHASE2_RUNTIME_ACCEPTANCE.md).
