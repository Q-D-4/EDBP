# EDBP security policy

EDBP is a security-sensitive Debian deployment project. Please report suspected vulnerabilities privately before public disclosure.

## Reporting a vulnerability

Prefer GitHub's private vulnerability-reporting workflow when it is available for this repository:

1. Open the repository's **Security** tab.
2. Open **Advisories**.
3. Use **Report a vulnerability** and provide the technical details privately.

If GitHub does not offer private vulnerability reporting to you, do **not** publish exploit details, credentials, sensitive logs, or a proof of concept in a public issue. Contact the maintainer through a non-public contact method associated with the project and request a private reporting channel.

A useful report should include, where applicable:

- affected EDBP version, commit, or ISO build;
- affected component and file path;
- prerequisites and threat model;
- reproducible steps;
- observed security impact;
- suggested mitigation, if known;
- whether the issue is already public or has been shared with another party.

Never include real passwords, private keys, production authorized keys, access tokens, or unrelated personal data. Use synthetic values when demonstrating an issue.

## Coordinated disclosure

Please allow time for the report to be reproduced, assessed, and fixed before public disclosure. Disclosure timing should be coordinated with the maintainer based on severity, exploitability, affected deployments, and availability of a mitigation.

Submitting a vulnerability report does not create a requirement to assign copyright or transfer ownership of independent research. Code submitted as a patch or pull request remains subject to `CONTRIBUTING.md` and the applicable file license.

## Scope

Security reports are particularly relevant for changes or vulnerabilities involving:

- Debian Installer and installation-time policy;
- boot and reboot flow;
- package/repository trust;
- authentication and local administrator handling;
- SSH configuration and host/user keys;
- firewall and network-isolation policy;
- USBGuard and peripheral policy;
- OOBE account/hostname provisioning;
- privilege boundaries and sudo;
- build-time secret handling;
- mechanisms that could introduce external traffic into an intended offline installation.

Vulnerabilities in third-party software shipped by an EDBP-built ISO may also need to be reported to the relevant upstream project. EDBP does not claim ownership of those upstream components.

## Supported code

Security maintenance is focused on the current `main` branch and the currently maintained EDBP release line. Historical commits, abandoned branches, and obsolete ISO builds may not receive fixes unless explicitly stated otherwise.

## Public issues

Public GitHub issues are appropriate for non-sensitive bugs and hardening proposals that do not disclose an unpatched vulnerability. When uncertain, report privately first.
