# Fresh Flathub acquisition — EDBP experimental build path

Each invocation of `make all` or `make build` first verifies source and then
starts a **new isolated system Flatpak installation** with `acquire-online`.
The tool installs only the three approved apps, their reviewed runtime closure,
and both explicitly selected GL extension branches. It exports the deployed
commits with `flatpak create-usb --system --allow-partial`, passing app and
non-Locale runtime refs explicitly while allowing Flatpak to include locale
extensions transitively. The complete 12-ref lock is nevertheless enforced
against the resulting export (missing/extra/wrong commits are rejected), then
verifies its
Collection ID/ref set and OSTree object integrity, stages the export in
`config/includes.chroot_after_packages/opt/edbp-build-inputs`, and writes the
new per-build `offline-lock.json` there.

The Live-Build hook checks the fresh-build marker, takes the generated lock,
checks the sideload repo, and performs an **offline-only** import in a dedicated
network namespace (`unshare --net`). It deliberately does not create a mount
namespace, because Live-Build uses chroot and `/` may not be a mountpoint.
The importer fails closed unless `/proc/self/ns/net` differs from PID 1 and
`/proc/net/dev` reports only loopback, with no IPv4 routes. The 090 hook
removes the temporary `/opt/edbp-build-inputs` transport tree from the final
root filesystem but retains the pinned lock at
`/usr/share/edbp/flatpak/offline-lock.json` for audit. The Makefile stores a
matching `edbp-<version>-amd64.flatpak-lock.json` external sidecar, includes it
in SHA256SUMS, and records its hash in the build manifest.

## Deliberate stop conditions

- Prior `chroot/` or `binary/` exists: **stop before any download**. This
  prevents Live-Build from resuming without re-copying new includes. Investigate
  and preserve any earlier failed build before explicitly resetting build state.
- An *unmanaged* payload currently exists in the staging destination: **stop**.
  Move the old payload to a safe location manually; never delete it via this
  tool. Previously-generated managed inputs may be deleted and replaced, but
  never silently used to satisfy a new build.
- Any new or missing runtime ref, app ref, incorrect Collection ID, or
  signature identity drift: **stop**, obtain security review and amend policy.
  `flatpak create-usb` does not authorize adding new runtimes automatically.
- Network or any signature/OSTree verification failure: **stop**, do not use
  the prior payload or the historical lock as a fallback. On a failed export,
  the root-owned (0700) temporary acquisition directory is retained for
  investigation; no future build automatically reuses it. Explicitly preserve
  evidence before a manual cleanup after review.
- The old committed offline-lock is historical: the live-build hook substitutes
  the generated per-build lock in the ISO. Never commit generated locks as
  generic source-tree changes or distribute an ISO with LAB credentials.

## Validation boundaries

Unit/source tests do not demonstrate access to Flathub, successful namespace
setup inside Live-Build, actual ISO boot, graphical KDE runtime, or successful
Debian Installer deployment. These require separate runtime/VM acceptance.
Use disposable LAB admin secrets and avoid production distribution.

**APT is separate.** Fresh Flatpak acquisition does not force APT to ignore
caches, choose unreleased Debian packages, or rebuild live-build from scratch.
A fully clean Debian package build requires a separate, explicitly reviewed
Live-Build reset/cache policy. The builder intentionally refuses implicit
`lb clean --purge`, `git clean`, or deleting existing build directories.
