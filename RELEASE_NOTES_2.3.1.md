# EDBP v2.3.1 — Brave Managed Policy Path Hotfix Candidate

**Status:** Source hotfix candidate only. Not a published release, distributable ISO, or approved Golden Master.

**Base:** public EDBP v2.3.0 source on protected `main`.

## Bug and field evidence

The managed DuckDuckGo search-policy JSON was present at
`/etc/brave-origin/policies/managed/policies.json` in the v2.3.0 laboratory
installation, but the Brave `brave://policy` page initially showed no managed
policies. On the test device, creating `/etc/brave/policies` as a symlink to
`/etc/brave-origin/policies` made the policies appear after restarting Brave.
This is an operator-reported physical-device test, not an independently
witnessed full v2.3.1 image acceptance.

## Source correction

- Preserve the existing reviewed Brave Origin managed-policy JSON unchanged.
- Add a relative image-include symlink:
  `/etc/brave/policies` -> `../brave-origin/policies`.
- Have the desktop-identity image build hook fail closed if the symlink is
  missing, replaced, or points to another path.
- Add a regression test for the link target, policy identity, and simulated
  image include copy.
- Advance source `VERSION` to `2.3.1`; do not relabel the older 2.3.0 ISO.

No new network access, policy keys, Flatpak changes, USBGuard changes,
nftables changes, or SSH changes are introduced.

## Release and provenance boundary

The tested v2.3.0 laboratory ISO and recovered checksums remain associated
with their original source commit, not this hotfix. Before any v2.3.1
distribution, verify this committed source and build and test a new
v2.3.1 image. The corrected build sidecar pipeline still requires complete
end-to-end acceptance. Never upload an ISO containing laboratory credentials.

The normative Golden Master requirements remain in
`EDBP-v2.2.0-SPECIFICATION.md` and are not yet certified.
