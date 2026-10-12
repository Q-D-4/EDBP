# EDBP — Source Publication Checklist

**Mode:** preparation and review only; **no automatic push, rebase, reset, force-push, tag or GitHub release**.

## Preserve the existing work

- Confirm the original feature worktree, detached acceptance worktree and their HEADs individually.
- The tested pilot was based on checkpoint `d002fac948973b74339b2ccceb525a73e215107c`, plus local Phase 2 worktree changes. Do not assume that GitHub already contains those changes.
- Inspect `git status --short`, `git diff --stat`, `git diff --check`, untracked files, and `git log --oneline --decorate --graph` before committing.
- Never move `main`, rewrite shared ancestry, or use `git push --force` simply to reduce a visible commit count. Protect original test logs and the build artifact outside the publishing commit set.

## Keep the original Arabic guide

- Move the **original local** `README.md` to `docs/BUILDING.ar.md` (after checking for an existing destination).
- Update its relative specification links from `./EDBP-v2.2.0-SPECIFICATION.md` to `../EDBP-v2.2.0-SPECIFICATION.md` and fix any other now-relative links.
- The guide predates Flatpak Phase 2: review build prerequisites and First-Boot workflow before publishing; don't pretend the old manual already covers the new feature.
- Replace only the repository root `README.md` with the candidate overview, after review.

## Code review and security gate

- Compare the full Phase 2 changes against the actual merge base and inspect all new files, including **untracked** files.
- Exclude: `secrets/`, SSH private keys, password hash inputs, staged installer preseed, build outputs, the pilot ISO, downloaded OSTree data, `chroot/`, `cache/`, log files and acceptance machine identifiers.
- The two checked-in APT vendor **public signing keyrings** are deliberate exceptions to the `*.key` ignore rule; verify their identity independently. Do not mistake them for secret keys.
- Verify no absolute paths under `/home/...`, lab SSH identities, tokens or personal device details leaked into documentation or code.
- Resolve any blockers without adding `trusted=yes`, `apt-secure false`, or disabling Flatpak trust checks.

## Suggested minimal commit structure

Prefer **two logically scoped commits** on the independent publication-review branch after all review gates pass:

1. `feat(flatpak): complete offline integration and first-boot provisioning` — source, systemd hooks, focused tests and security checks.
2. `docs: modernize project overview and record Phase 2 pilot` — root README, preserved Arabic guide, release notes and acceptance evidence.

If installer changes are large or independent, split them into a third `fix(installer): defer Flatseal provisioning until first boot` commit. Do not create a separate commit for each debug attempt or failed ISO build. Do not squash commits that may already be shared; inspect merge-base and remote tracking first.

## Evidence and release gate

- Preserve the single-device pilot results accurately; do not call it a complete Golden Master.
- Run all source gates required by the latest repository version on a **clean committed tree** before publication.
- Confirm package manifests, build provenance, source license and documentation links.
- A clean production image build, second independent installation and other gates in `EDBP-v2.2.0-SPECIFICATION.md` remain separate from publishing reviewed source.
- **Never publish the laboratory ISO**: it embeds lab administrator password-hash material even if the hash is not human-readable.

## Publication approval

Only after reviewing the final file list, `git diff --cached`, branch ancestry, remote destination, public visibility, and commit messages should an operator choose to push. Prefer a feature-branch push and pull request with review; no direct-to-main force updates.
