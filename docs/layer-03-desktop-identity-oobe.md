# EDBP Layer 03 — Desktop, Identity, Policies, and OOBE

This layer supplies system-wide desktop policy and the one-time first-boot
workflow. It does **not** create `localadmin`; the interactive installer layer
must create that account with a unique credential and membership in `sudo`.
The OOBE deliberately fails closed if this prerequisite is absent.

## Source-to-runtime path map

All source files below are under
`config/includes.chroot_after_packages/`. The corresponding path in the final
Live/install filesystem is the same path after that prefix is removed.

| Runtime path | Purpose |
|---|---|
| `/etc/sddm.conf.d/hide-admin.conf` | Hides `localadmin` and prevents SDDM from remembering the last user. |
| `/etc/sudoers.d/localadmin` | Grants password-authenticated full sudo to `localadmin`; no `NOPASSWD`. |
| `/usr/local/sbin/edbp-oobe` | Validated first-boot account/hostname workflow. |
| `/etc/systemd/system/edbp-oobe.service` | Runs the workflow once on TTY1 and skips the Live session. |
| `/etc/systemd/system/sddm.service.d/10-edbp-oobe.conf` | Makes successful OOBE a prerequisite of SDDM. |
| `/etc/brave/policies/managed/policies.json` | Managed Brave homepage, startup, new-tab, and DuckDuckGo policy. |
| `/etc/libreoffice/registry/edbp-defaults.xcd` | Locked LibreOffice UI, language, and default-save policy. |
| `/etc/xdg/kxkbrc` | Locked Plasma `us,ara` keyboard policy. |
| `/etc/xdg/plasma-localerc` | Locked English Plasma locale policy. |
| `/etc/xdg/mimeapps.list` | System defaults for Microsoft Office MIME types. |
| `/etc/default/keyboard` | Non-Plasma/XKB defaults for the installed system and SDDM. |
| `/etc/locale.conf` and `/etc/locale.gen` | English system locale plus generated English/Arabic locales. Debian supplies `/etc/default/locale` as a compatibility symlink. |

`040-configure-desktop-identity.hook.chroot` sets security-sensitive modes,
validates sudoers/JSON/XML/shell syntax, generates locales, exposes the
LibreOffice policy to its scanned registry directory, and enables OOBE.

## Identity and SDDM semantics

`HideUsers=localadmin` is cosmetic privacy, not access control. It removes the
account from the chooser, but a display manager may still accept a manually
typed account name. If graphical login by `localadmin` must be prohibited, add
a reviewed PAM rule later; do not mistake hiding for denial.

`RememberLastUser=false` prevents an administrative login from re-exposing the
name through SDDM state. The sudo rule is the normal Debian full-elevation rule:

```sudoers
localadmin ALL=(ALL:ALL) ALL
```

Passwordless elevation is intentionally not configured. The installer must
also add `localadmin` to the `sudo` group because layer 02 delegates USBGuard
IPC to that group. The OOBE checks this condition before changing the machine.

## OOBE boot and completion model

The service is enabled under `graphical.target`, and the SDDM drop-in also
pulls it as a required dependency. On a first installed-system boot:

1. systemd checks that `/run/live/medium` and
   `/var/lib/edbp/oobe-complete` are absent;
2. TTY1 getty is stopped for the duration, TTY1 is activated, and `whiptail`
   starts before SDDM;
3. the script verifies that it is root, required tools/files exist,
   `localadmin` exists, and `localadmin` belongs to `sudo`;
4. it requests a single-label RFC-style hostname, an unused standard-user
   name, and a hidden password entered twice;
5. all input is validated and summarized before any persistent mutation;
6. the account is created with a private primary group and no supplementary
   groups, then its password is passed to `chpasswd` over stdin rather than a
   process argument;
7. `/etc/hostname` and the `127.0.1.1` entry in `/etc/hosts` are replaced from
   temporary files and the running static hostname is updated;
8. an atomic `/var/lib/edbp/oobe-complete` marker is written, normal enablement
   of the OOBE unit is removed, and SDDM is allowed to start.

The marker is the authoritative at-most-once control. Disabling the service
alone is insufficient because the SDDM dependency can still activate a
disabled unit. Conversely, deleting the packaged unit after success would make
fleet repair, package verification, and incident analysis worse. The unit is
therefore retained, disabled, and condition-gated rather than self-deleted.

If any operation fails before the marker is committed, the script restores the
old hostname files and removes the partially created account/home. The unit
fails, so SDDM remains blocked instead of presenting an unusable or unmanaged
desktop. Recovery remains possible as `localadmin` on another TTY or through
the separately reviewed SSH path. After repairing the cause:

```sh
sudo systemctl start edbp-oobe.service
```

To intentionally re-run OOBE on a laboratory machine, first remove the marker
under a controlled change procedure. Doing so on a deployed endpoint creates
another local account and must not be a normal help-desk action.

The wizard uses English text because the Linux virtual console does not render
Arabic shaping and bidirectional text reliably. A root graphical wizard before
the display manager would require display authorization and a larger privileged
GUI stack, so it is not used.

## Brave policy

The managed JSON sets all three distinct browser entry points:

- Home button: `HomepageLocation`;
- process startup: `RestoreOnStartup=4` and `RestoreOnStartupURLs`;
- new tabs: `NewTabPageLocation`.

The portal is configured as `https://home.mofa.sy/`. If it uses a private CA,
that CA must be deployed through a separately reviewed system trust package.
Silently downgrading an enterprise portal to HTTP is not acceptable. The
DuckDuckGo search and suggestion URLs contain Chromium's required
`{searchTerms}` replacement token and are managed, so users cannot replace the
default provider through normal Brave settings.

## LibreOffice policy

The requested `.xcu` filename was corrected to `.xcd`. An `.xcu` file is a
user-layer change set (normally `registrymodifications.xcu`); Debian 13's
LibreOffice 25.2 shared registry consumes `.xcd` data layers. The source policy
lives under `/etc`, while the build hook creates this scanned link:

```text
/usr/lib/libreoffice/share/registry/zz-edbp-defaults.xcd
  -> /etc/libreoffice/registry/edbp-defaults.xcd
```

The `zz-` name ensures the override is loaded after Writer, Calc, and Impress
module data. `oor:finalized="true"` locks the selected values against per-user
profiles. The policy selects:

- Arabic LibreOffice UI (`ooLocale=ar`);
- the `Tabbed` mode and `notebookbar.ui` implementation for Writer, Calc, and
  Impress;
- `Office Open XML Text` for DOCX;
- `Calc MS Excel 2007 XML` for XLSX;
- `Impress MS PowerPoint 2007 XML` for PPTX.

OOXML is not LibreOffice's native model. Features without exact Microsoft
format equivalents can be changed or lost, so the normal format warning is not
suppressed. The system MIME defaults open common legacy and OOXML Word, Excel,
and PowerPoint types with the appropriate LibreOffice module.

## KDE locale and keyboard policy

Plasma reads cascading KConfig files from `/etc/xdg` before the user's config.
Each EDBP key uses the official `[$i]` immutable marker, so a user-level
`~/.config/kxkbrc` or `plasma-localerc` cannot override the policy.

The two layouts are `us,ara`, the switch policy is global, and
`grp:alt_shift_toggle` expands in xkeyboard-config to both the left
Alt+left Shift and right Alt+right Shift combinations. `/etc/default/keyboard`
provides the same XKB values outside the Plasma user session. Plasma and SDDM
remain English even though LibreOffice is deliberately Arabic.

## Direct package dependencies

`identity-oobe.list.chroot` makes implicit base assumptions explicit:

- `whiptail`: small TTY dialog frontend;
- `passwd`: `useradd`, `userdel`, and `chpasswd`;
- `python3-minimal`: deterministic build-time JSON/XML validation (already
  required transitively by the accepted HPLIP stack);
- `kbd`: `chvt`, used to make TTY1 visible even when a splash screen was active.

With this list added, the complete tree contains 97 unique direct package
entries. A fresh Trixie simulation with APT Recommends disabled resolved 1,269
packages and selected none of the explicitly rejected Bluetooth/Discover or
vendor beta/nightly packages. This is dependency resolution, not a successful
ISO build or boot test.

## Remaining prerequisites and acceptance tests

This layer is not independently releasable. Before testing first boot, the
installer/Preseed layer must create `localadmin`, add it to `sudo`, and define a
per-device credential/SSH-key enrollment method without embedding a shared
secret in Git or the ISO.

Minimum installed-system tests:

```sh
systemctl status edbp-oobe.service sddm.service
test -f /var/lib/edbp/oobe-complete
id localadmin
id STANDARD_USER
sudo visudo --check --file /etc/sudoers.d/localadmin
hostnamectl status
python3 -m json.tool /etc/brave/policies/managed/policies.json >/dev/null
```

Brave policy must also be inspected at `brave://policy`, and LibreOffice must
be launched with a clean user profile to verify Arabic UI, Tabbed mode, and the
three default-save filters. Those GUI checks cannot be replaced by XML/JSON
syntax validation.
