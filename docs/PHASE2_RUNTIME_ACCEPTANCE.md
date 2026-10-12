# EDBP Phase 2 — Physical-Device Runtime Acceptance

**Date:** 2026-10-12

**Status:** Observed pilot acceptance passed within the scope below; formal Golden Master gates remain open.

**Platform:** Debian 13 (Trixie), amd64, UEFI, KDE Plasma 6

## Candidate provenance

| Field | Evidence |
| --- | --- |
| Local source checkpoint | `d002fac948973b74339b2ccceb525a73e215107c` plus uncommitted reviewed Phase 2 fixes |
| Laboratory ISO | `edbp-2.2.0-amd64.hybrid.iso` |
| SHA-256 | `a78a02a5e0a8e07ae82c0c126611aa43a6a9d50b76d535f72fdb542d10b0e094` |
| Build result | `BUILD RESULT: PASS` |
| ISO structure | ISO 9660; El Torito UEFI image at `/boot/grub/efi.img`; `/live/filesystem.squashfs` present |

**Traceability limitation:** the hardware-pilot ISO was built from a local candidate with changes that had not yet been committed into a final release commit. This digest does **not** bind a future Git tag to the tested image. A separately verified clean release build is still required.

**Credential handling:** this ISO contains laboratory build inputs and must not be publicly distributed. The path, username, hostname and credentials of the test workstation are intentionally omitted.

## Hardware pilot observations

| Gate | Result | Evidence |
| --- | --- | --- |
| UEFI boot and installation | PASS | Boot and installer completed on the test device |
| First-boot Flatseal provisioning | PASS | `edbp-flatseal-provision.service`: `Result=success`, `ExecMainStatus=0` |
| Flatpak refs verified | PASS (helper report) | `PASS: 11 system refs and admin-only Flatseal pinned/verified` |
| Admin-only Flatseal | PASS (tested install scope) | `flatpak info --user` succeeds for `edbpadmin`, fails for regular user; `--system` fails |
| Flatseal GUI | PASS | Opened in an administrative desktop session |
| OOBE | PASS | OOBE service succeeded; ordinary non-sudo account created |
| Second boot | PASS | Services retained expected state; apps remained installed |
| ONLYOFFICE | PASS | GUI launched and behaved normally |
| RustDesk | PASS | GUI launched and behaved normally |
| Restricted/offline network | PASS (GUI launch only) | Applications launched with the no-public-Internet `nftables` baseline active |

The test device exposed system-wide Flatpak applications `org.onlyoffice.desktopeditors` (observed version `9.4.0`) and `com.rustdesk.RustDesk` (observed version `1.5.0`). Flatseal was installed in the administrator's user scope as version `2.4.1`.

Service journal excerpt (redacted to avoid identifying the workstation):

```text
flatpak: user: Installed app/com.github.tchx84.Flatseal/x86_64/stable from flatseal-origin
flatpak: system: Uninstalled app/com.github.tchx84.Flatseal/x86_64/stable
edbp-flatseal-admin: PASS: 11 system refs and admin-only Flatseal pinned/verified
edbp-flatseal-admin: PASS: Flatseal installed for edbpadmin only; system app removed
systemd: Finished edbp-flatseal-provision.service
systemd: Finished edbp-oobe.service
```

## Boundaries and unresolved release gates

1. The pilot did not establish full reproducibility between clean committed source and independently rebuilt production ISO.
2. A second independent UEFI installation and any required forensic tests remain to be completed according to the normative specification.
3. Peripheral inventory, USBGuard exceptions, site networking rules, printing/scanning and institutional security review remain deployment-specific acceptance items.
4. RustDesk remote session connectivity was **not** tested. A launched GUI does not imply public-Internet access under restrictive `nftables` rules.
5. Flatseal being absent in ordinary user scope does not, by itself, prove that a user can never install Flatpak packages by other means. This report does not claim that additional policy enforcement was tested.
6. Security and operational release sign-off, credentials handling and artifact provenance must be recorded separately.

## Decision

**Phase 2 functional pilot: PASS. Production/Golden Master authorization: PENDING. Phase 3: not authorized.**
