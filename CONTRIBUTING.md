# Contributing to EDBP

EDBP accepts contributions under the licensing and provenance rules described in this repository.

## License of contributions

Unless a file states otherwise, contributions to EDBP-original software and copyrightable configuration are submitted under `GPL-3.0-or-later`.

A contribution to a file with a different or upstream-derived license must remain compatible with, and preserve, that file's existing license and attribution. See `LICENSING.md` and `THIRD_PARTY_NOTICES.md` before modifying such files.

Do not remove or weaken SPDX identifiers, copyright notices, provenance comments, or third-party attribution without an explicit licensing review.

## Developer Certificate of Origin

Every commit intended for inclusion in EDBP must carry a Developer Certificate of Origin sign-off.

Create signed-off commits with:

```bash
git commit -s
```

This appends a line of the form:

```text
Signed-off-by: Full Name <email@example.com>
```

By adding that sign-off, you certify the Developer Certificate of Origin 1.1 contained in the repository's `DCO` file.

The sign-off is a provenance certification. It does not transfer your copyright to the EDBP maintainer.

## Contribution provenance

Only submit material that you have the legal right to contribute under the applicable license.

If a change incorporates or adapts upstream material, the pull request must identify:

- upstream project;
- exact source file or documentation source;
- version, tag, or commit where practical;
- upstream license;
- what was copied, adapted, or used only as an interface reference.

Do not submit copied code or configuration with unknown provenance.

## Third-party and organization-owned material

Files identified in `THIRD_PARTY_NOTICES.md` are not automatically covered by the default EDBP GPL grant.

Do not relicense, replace attribution on, or broaden redistribution rights for organization-owned or vendor material unless the relevant rights holder has authorized the change.

## Security-sensitive changes

EDBP is a security-sensitive Debian deployment project. Changes affecting installer behavior, authentication, SSH, firewalling, USB policy, boot flow, package trust, secrets handling, or other security controls must explain the security impact and preserve fail-closed behavior where the existing design requires it.

Do not place passwords, password hashes, private keys, production authorized keys, access tokens, or other secrets in commits, issues, pull requests, test fixtures, or logs.

Potential vulnerabilities must be reported according to `SECURITY.md`, not disclosed first in a public issue.

## Validation

Before submitting a pull request, run the repository's applicable static verification and tests. For a normal full verification on a supported build host:

```bash
make verify
```

If a change affects a targeted policy with a dedicated test, run that test as well.

A pull request should describe what was changed, why it was changed, what was tested, and any provenance or licensing implications.

## Pull requests and review

Keep changes focused. Do not bundle unrelated refactors, policy changes, dependency changes, and licensing changes in one pull request without a clear reason.

Maintainers may require additional provenance evidence, security review, or licensing clarification before accepting a contribution.
