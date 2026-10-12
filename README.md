# EDBP

**Enterprise Debian Build Platform**

An institution-neutral Debian workstation image built with `live-build`. EDBP combines a minimal KDE Plasma desktop, an offline-capable installer, centrally defined security defaults, and a reviewed Flatpak application set in a single auditable source tree.

**Debian 13 (Trixie)** · **amd64** · **UEFI** · **KDE Plasma 6** · **GPLv3**

**Source version:** `2.3.0` — *release candidate in preparation*. This is not a published GitHub Release, signed tag, distributable ISO or approved Golden Master. The v2.2.0 specification remains the documented normative baseline pending an explicitly reviewed revision.

> [!IMPORTANT]
> **Engineering project, not a universal ready-to-deploy ISO.** Building an image and completing a hardware pilot do not constitute production approval. Review the [release acceptance requirements](EDBP-v2.2.0-SPECIFICATION.md) and adapt site-specific policies downstream before deployment.

[Features](#what-edbp-provides) · [Security](#security-model) · [Flatpak integration](#flatpak-integration) · [Build](#building-edbp) · [Documentation](#documentation) · [Project status](#verification-and-release-status)

## What EDBP provides

| Area | Implementation |
| --- | --- |
| Operating system | Debian 13 (Trixie), `amd64`; minimal KDE Plasma 6 with SDDM |
| Installation | Hybrid Live ISO and graphical Debian Installer, targeting UEFI/GPT |
| Offline deployment | Installer consumes image-local content; target workstations do not need an APT mirror during installation |
| First boot | Systemd-gated provisioning followed by interactive OOBE for hostname and daily-user creation |
| Administration | Dedicated `edbpadmin` account; ordinary users are not granted `sudo` |
| Endpoint controls | Baseline `nftables`, USBGuard, restricted SSH and disabled Bluetooth |
| Applications | System-wide ONLYOFFICE Desktop Editors and RustDesk; Flatseal provisioned only for `edbpadmin` |
| Verification | Source checks, policy regression tests, manifest/checksum generation and runtime acceptance procedures |

### Deployment lifecycle

```text
       Source + reviewed configuration + operator-supplied credentials
                                   |
                    Verify and build on a trusted host
                                   |
                   Hybrid Debian 13 Live / UEFI ISO
                                   |
               Guided installation (no target Internet)
                                   |
                 First-boot Flatpak provisioning gate
                                   |
                 OOBE: hostname + daily user account
                                   |
                   KDE Plasma workstation session
```

The source repository is generic by design: institutional branding, internal repositories, network access rules and deployment credentials belong in separately reviewed **downstream configurations**.

## Security model

EDBP takes a conservative approach to first-run access and privileges:

- **Separate identities:** `edbpadmin` handles controlled maintenance; the account created during OOBE has no administrative privileges.
- **Restrictive networking:** the default `nftables` policy does **not** permit general public-Internet egress. Workstation-specific connectivity must be reviewed and configured downstream. A locally launching application is not proof of remote connectivity.
- **Device control:** USBGuard restricts unsupported USB interfaces, including mass-storage devices, according to the configured policy.
- **Remote administration:** SSH is restricted to reviewed public-key authentication for the administrative account; per-device SSH host keys are generated during installation.
- **Build-time secrets:** administrative password hashes and SSH public keys are supplied locally and must not be committed. A password hash included in an installation image can be extracted and attacked offline; treat the resulting ISO as sensitive.
- **Repository verification:** third-party APT and Flatpak sources must retain signature and trust validation; do not disable signature enforcement to work around build failures.

These defaults may be too restrictive for a specific deployment. That is intentional: **site policy must be explicit**, not hidden inside the public upstream.

See the [normative project specification](EDBP-v2.2.0-SPECIFICATION.md) for the detailed threat model, limitations and required release gates.

## Flatpak integration

The enterprise Flatpak workflow is designed around **fresh acquisition on the connected build host** and **offline provisioning on the deployed workstation**.

1. The build verifies the reviewed application catalog and trust material.
2. A fresh, isolated Flathub acquisition and staged OSTree content are validated before image assembly.
3. Installer-time checks verify staged material without relying on a target D-Bus session.
4. On first boot, `edbp-flatseal-provision.service` provisions and verifies Flatseal for `edbpadmin` before OOBE and normal desktop login proceed.
5. The general-purpose system installation retains ONLYOFFICE and RustDesk; Flatseal is not left installed system-wide.

**Flatseal's user-scoped installation is not a blanket authorization policy.** Its installation scope and the ability to install or administer software are distinct controls.

Implementation notes: [Flatpak Phase 2](FLATPAK_PHASE2.md) · [Hardware acceptance evidence](docs/PHASE2_RUNTIME_ACCEPTANCE.md).

## Building EDBP

Use a trusted, supported build environment with sufficient disk space and network access to Debian package mirrors, vendor repositories and Flathub. The project documentation specifies **Debian 13** as the build-host baseline. Actual build-host requirements and package names are documented in the [Arabic build and installation guide](docs/BUILDING.ar.md).

```bash
git clone https://github.com/Q-D-4/EDBP.git
cd EDBP

# Install build prerequisites and prepare local administrator inputs
# using docs/BUILDING.ar.md. Never commit secrets/.

make verify
make verify-flatpak
make all
```

`make verify` requires the administrator input files to be prepared correctly. `make all` verifies and builds the ISO and generates integrity/provenance artifacts. Building requires Internet access; installation of the resulting image is designed to work offline.

> [!CAUTION]
> `make clean` purges live-build state and cached downloads. **Do not** use `git clean -fdx` or `git reset --hard` as routine cleanup, and never run either against a working tree containing unrecoverable credentials or uncommitted work.

### Installation

Boot the image in **UEFI mode** using an appropriate installer medium (including a compatible Ventoy installation), and install to a dedicated test disk first. Partition selection remains interactive and **can destroy data on the selected disk**. After installation, the first-boot gate and OOBE prepare the administrative and daily-user environments.

Follow the [full installation procedure](docs/BUILDING.ar.md), not this overview, when preparing a real workstation.

## Verification and release status

The following **documented v2.2.0 Phase 2** pilot covered one physical workstation. A separate clean v2.2.0 source build and subsequent hardware run were also reported, but are not substitutes for formal v2.3.0 release acceptance. The documented pilot covered:

- UEFI image structure and ISO SHA-256 integrity.
- Debian 13 installation, initial startup and a subsequent reboot.
- Successful systemd First-Boot and OOBE execution.
- Administrator-scoped Flatseal installation and GUI launch.
- ONLYOFFICE and RustDesk GUI launch under the restrictive offline network baseline.

**This is not a Golden Master certification.** The [specification](EDBP-v2.2.0-SPECIFICATION.md) requires additional independent installation, security, hardware-inventory and operational sign-off gates. A test ISO containing laboratory credentials is **not a distributable production artifact**.

Read [Phase 2 acceptance evidence](docs/PHASE2_RUNTIME_ACCEPTANCE.md), [Phase 2 release notes](RELEASE_NOTES_PHASE2.md), and [v2.3.0 candidate notes](RELEASE_NOTES_2.3.0.md) for the exact evidence boundaries and remaining gates.

## Repository map

| Path | Purpose |
| --- | --- |
| `auto/`, `config/` | Live-build configuration, image content, hooks and policies |
| `scripts/` | Build preparation, verification and provisioning helpers |
| `tests/` | Automated policy and workflow regression tests |
| `EDBP-v2.2.0-SPECIFICATION.md` | Normative architecture and release gates |
| `FLATPAK_PHASE2.md` | Flatpak implementation checkpoint and evidence |
| `docs/BUILDING.ar.md` | Detailed Arabic build, installation and maintenance guide |
| `docs/PHASE2_RUNTIME_ACCEPTANCE.md` | Physical-device acceptance observations |
| `RELEASE_NOTES_PHASE2.md` | Historical Phase 2 pilot notes and limitations |
| `RELEASE_NOTES_2.3.0.md` | New version candidate scope and uncompleted release gates |
| `LICENSE`, `LICENSES/` | Project and third-party license materials |

## Documentation

- **[Build & installation guide — العربية](docs/BUILDING.ar.md)**: prerequisites, credential preparation, ISO creation, USB/installer, OOBE and troubleshooting.
- **[Technical specification](EDBP-v2.2.0-SPECIFICATION.md)**: normative architecture, security posture and Golden Master criteria.
- **[Flatpak Phase 2](FLATPAK_PHASE2.md)**: design and verification checkpoint.
- **[Physical-device acceptance](docs/PHASE2_RUNTIME_ACCEPTANCE.md)**: what was actually observed, and what remains unverified.
- **[Phase 2 pilot notes](RELEASE_NOTES_PHASE2.md)**: historical improvements and constraints.
- **[v2.3.0 candidate notes](RELEASE_NOTES_2.3.0.md)**: version transition and release gates.

## Contributions and responsible disclosure

Changes should be reviewable, scoped and supported by focused tests. Do not include production-specific data, build secrets, generated images or personal identifiers in pull requests. Use the existing [contribution guidelines](CONTRIBUTING.md). For security-sensitive findings, avoid disclosing exploit details or credentials in a public issue.

## License

EDBP's project license is **GNU General Public License, version 3**; see [LICENSE](LICENSE). Third-party packages and bundled materials retain their respective license obligations; consult [LICENSES/](LICENSES/).
