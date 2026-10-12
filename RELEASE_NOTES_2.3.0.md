# EDBP v2.3.0 — Candidate Preparation Notes

**Status:** Source-version preparation only; **not a published release or an approved Golden Master**.

**Platform:** Debian 13 (Trixie), amd64, UEFI, KDE Plasma 6.

**Version source:** `VERSION` = `2.3.0`.

## Scope of this candidate

- Advance the source version from `2.2.0` to `2.3.0` (minor release because the already-integrated Phase 2 Flatpak delivery adds functionality).
- Keep the existing Phase 2 Flatpak implementation and its tests unchanged.
- Correct forward-looking build documentation to name the version-derived ISO output.
- Preserve `EDBP-v2.2.0-SPECIFICATION.md`, `RELEASE_NOTES_PHASE2.md`, and `docs/PHASE2_RUNTIME_ACCEPTANCE.md` as historical/normative baseline records rather than rewriting their observed evidence.
- Continue to prohibit the publication of laboratory ISO files or administrator credential inputs.

This candidate does **not** introduce new application versions, broaden network access, authorize Phase 3, or certify any additional hardware or security properties.

## Available previous-version evidence

The Phase 2 feature set was merged into public `main` via PR #1 after 22/22 final independent fresh-clone source checks, DCO and official REUSE validation. A separate clean build of the **v2.2.0** ISO completed with all four SHA-256 sidecar checks passing. A subsequent physical-device installation was reported functional; the recorded acceptance boundaries are in `docs/PHASE2_RUNTIME_ACCEPTANCE.md`.

**Provenance boundary:** none of those checks establishes that a **v2.3.0 ISO** has been built, installed, or approved. Changing `VERSION` changes image naming and metadata. A new build and acceptance record must identify the final commit SHA and the new ISO SHA-256.

## Required gates before any v2.3.0 tag or GitHub Release

1. Review and DCO-sign the release-preparation commit on an isolated branch, then merge through the protected-`main` pull-request workflow.
2. Pass source, Flatpak, test, link and REUSE licensing checks on an **anonymous clean clone of the exact committed revision**.
3. Build the v2.3.0 ISO from a **clean committed tree** on Debian 13 with separately controlled laboratory administrator inputs. Preserve the image digest, lockfile, package manifest, build-input hashes, and commit-to-image provenance.
4. Verify boot/install/first boot/OOBE, Flatseal administrative scope, ONLYOFFICE/RustDesk GUI, offline installation and required security policies on a fresh test device. Record what was actually observed; do not infer network functionality from GUI launch.
5. Complete the remaining requirements of `EDBP-v2.2.0-SPECIFICATION.md` or an explicitly reviewed successor, including independent installation, peripherals, firewall/site security sign-off and credential governance, before asserting Golden Master status.
6. Only after approval, create a signed or otherwise verified release tag and a distributable artifact **without embedded laboratory credentials**. Do not publish any test ISO or generated secret-bearing build inputs.

## Sources of truth

- Architecture and Golden Master criteria: [`EDBP-v2.2.0-SPECIFICATION.md`](EDBP-v2.2.0-SPECIFICATION.md).
- Historical Phase 2 implementation/pilot: [`RELEASE_NOTES_PHASE2.md`](RELEASE_NOTES_PHASE2.md), [`docs/PHASE2_RUNTIME_ACCEPTANCE.md`](docs/PHASE2_RUNTIME_ACCEPTANCE.md).
- Safe build preparation: [`docs/BUILDING.ar.md`](docs/BUILDING.ar.md).
