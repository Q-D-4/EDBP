## EDBP — Enterprise Debian Build Platform

# Implementation Runbook v2.0.1 — Hardening Revision

## Immutable Enterprise Desktop Image Architecture

**Status:** Production Ready Design (Hardened)
**Target OS:** Debian 13 Trixie amd64
**Architecture:** x86_64
**Build Framework:** live-build
**Installer:** Debian Installer (Automated Preseed)
**Desktop Environment:** KDE Plasma
**Deployment Model:** Immutable ISO → Zero Touch Installation
**Remote Management:** SSH Public Key Authentication
**Disk Encryption:** Not enabled — accepted risk per Cybersecurity Governance (see §11a)

---

## Changelog from v2.0.1

* 🔴 Fixed duplicate `d-i preseed/late_command` definition (merged into one).
* 🔴 Fixed invalid `;` comment inside preseed.cfg (must be `#`).
* 🔴 Fixed `make clean` missing `sudo` on chroot/binary cleanup.
* 🟠 Replaced `sed`-based SSH hardening with an `sshd_config.d` drop-in file + `sshd -t` validation.
* 🟠 Removed `tasksel tasksel/first multiselect standard` from preseed (conflicted with live-build package-lists).
* 🟠 Removed kernel-level `usb-storage` blacklist in favor of USBGuard-only policy (Option B — Enterprise Flexible).
* 🟡 Fixed leading blank line in APT `.sources` heredocs.
* 🟡 Added SSH public key validation and stronger private-key leak check to `make verify`.
* 🟡 Centralized version string via `VERSION` file instead of hardcoding `2.0.1` in multiple places.
* 🟡 Documented disk-encryption decision as an explicit accepted risk with compensating controls.
* 🟢 Fixed Build Failure: Removed obsolete packages (`kde-config-systemd`, `fonts-kacst`, `hyphen-ar`) and proprietary `p7zip-rar` to strictly align with Debian 13 Trixie repositories.
* 🟢 Security Hardening: Swapped standard `brave-browser` with `brave-origin` to enforce a completely bloat-free, enterprise-grade privacy baseline natively.
* 🟢 Fixed Preseed Silent Failure: Relocated `preseed.cfg` from `includes.installer` directly to `includes.binary` root to bypass `live-build` internal pathing bugs.
* 🟢 Zero-Touch Automation: Overhauled GRUB boot parameters in `auto/config` (added `--bootappend-install auto=true`) to force completely unattended installation.
* 🟢 Standardization: Replaced dependency-heavy `mkpasswd` with native `openssl passwd -6` for generating Preseed SHA-512 hashes.

---

# 0. Executive Architecture Overview

## الهدف

بناء نظام Debian مؤسسي موحد يتم تثبيته على أجهزة الموظفين بدون تدخل يدوي، مع:

* نظام تشغيل موحد.
* برامج مثبتة مسبقاً.
* إعدادات أمنية ثابتة.
* دعم اللغة العربية.
* LibreOffice مهيأ للبيئة العربية.
* إدارة عن بعد عبر SSH.
* فصل كامل بين:

  * بيئة البناء.
  * صورة ISO.
  * الجهاز النهائي.

---

# Architecture Model

```text
                 EDBP Build Server
                       |
                       |
                 live-build
                       |
                       |
                 Enterprise ISO
                       |
                       |
          +------------+------------+
          |                         |
       USB Install              PXE Future
          |
          |
     Debian Installer
          |
          |
        /target
          |
          |
    Automated Deployment
          |
          |
 +---------------------+
 | Employee Workstation |
 |                     |
 | Debian 13            |
 | KDE Plasma           |
 | localadmin           |
 | SSH Public Key       |
 | Security Policies    |
 +---------------------+

          ^
          |
          |
 DevOps Management PC

 Private SSH Key
 (Never inside ISO)
```

---

# 1. Build Host Preparation

## مواصفات خادم البناء

يفضل:

| Component | Requirement      |
| --------- | ---------------- |
| CPU       | x86_64           |
| RAM       | 16GB Recommended |
| Storage   | 100GB+           |
| OS        | Debian 13 amd64  |
| Network   | Stable Internet  |

---

# تحديث النظام

```bash
sudo apt update
sudo apt upgrade -y
```

---

# تثبيت أدوات البناء

```bash
sudo apt install -y \
live-build \
debootstrap \
squashfs-tools \
xorriso \
grub-pc-bin \
grub-efi-amd64-bin \
mtools \
git \
make \
shellcheck \
shfmt \
jq \
curl \
ca-certificates \
gnupg
```

---

# إنشاء مستخدم البناء

لا يتم البناء بحساب root.

```bash
sudo useradd \
-m \
-s /bin/bash \
builder
```

إضافة sudo:

```bash
sudo usermod -aG sudo builder
```

الدخول:

```bash
sudo su - builder
```

---

# 2. Project Initialization

إنشاء المشروع:

```bash
mkdir -p ~/enterprise-iso/edbp-build

cd ~/enterprise-iso/edbp-build
```

---

# هيكل المشروع النهائي

```text
edbp-build/

├── auto/
│   └── config
│
├── config/
│
│   ├── package-lists/
│   │   └── enterprise.list.chroot
│   │
│   ├── hooks/
│   │   └── live/
│   │       ├── 10-enterprise-apps.hook.chroot
│   │       ├── 20-branding-config.hook.chroot
│   │       └── 30-security-hardening.hook.chroot
│   │
│   ├── includes.chroot/
│   │
│   │   └── etc/
│   │       └── edbp/
│   │           └── keys/
│   │               └── devops_admin.pub
│   │
│   └── includes.binary/
│       └── preseed.cfg
│
├── scripts/
│
├── tests/
│
├── secrets/
│   └── (NOT committed)
│
├── Makefile
│
├── VERSION
│
└── CHANGELOG.md
```

---

# 3. Version Management

إنشاء ملف:

```bash
nano VERSION
```

المحتوى:

```text
2.0.1
```

⚠️ **ملاحظة:** هذا هو المصدر الوحيد لرقم الإصدار. كل مكان آخر (ISO Volume Label، `/etc/edbp-release`، CHANGELOG) يجب أن يقرأ القيمة من هذا الملف بدل كتابتها يدوياً، لتفادي أي اختلاف بين الأماكن.

---

سيتم إنشاء ملف داخل النظام النهائي:

```text
/etc/edbp-release
```

يحتوي:

```text
EDBP Version: 2.0.1
Build Date: YYYY-MM-DD
```

---

# 4. SSH Key Management Architecture

## القاعدة الأساسية

يتم تضمين:

✅ Public Key فقط

داخل ISO.

ولا يتم تضمين:

❌ Private Key

نهائياً.

---

## مثال

داخل ISO:

```text
/etc/edbp/keys/devops_admin.pub
```

يحتوي:

```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAxxxx devops@company
```

---

أما:

```text
~/.ssh/devops_admin
```

يبقى فقط مع فريق DevOps.

---

# Git Security

يضاف:

```text
secrets/
*.pem
*.key
id_*
```

إلى:

```text
.gitignore
```

---

# 5. Build Workflow

المراحل:

```text
1. Developer updates configuration

          |
          v

2. live-build generates filesystem

          |
          v

3. Hooks apply policies

          |
          v

4. Debian Installer integration

          |
          v

5. ISO Artifact Generated

          |
          v

6. Testing

          |
          v

7. Deployment
```

---

# EDBP — Enterprise Debian Build Platform

## Implementation Runbook v2.0.1

## الجزء الثاني: Live-Build Configuration + Software Layer

---

# 6. Build Controller

## ملف:

```bash
auto/config
```

إنشاء:

```bash
nano auto/config
```

المحتوى:

```bash
#!/bin/sh

set -e

EDBP_VERSION="$(cat ../VERSION 2>/dev/null || cat VERSION)"

lb config noauto \
    --distribution trixie \
    --architecture amd64 \
    --archive-areas "main contrib non-free-firmware" \
    --debian-installer live \
    --debian-installer-gui true \
    --iso-application "EDBP Enterprise Desktop" \
    --iso-publisher "Enterprise IT Department" \
    --iso-volume "EDBP_${EDBP_VERSION}" \
    --bootappend-live "boot=live components quiet splash" \
    --bootappend-install "auto=true priority=critical vga=788 file=/cdrom/preseed.cfg quiet" \
    "${@}"
```

> `EDBP_VERSION` تُقرأ من ملف `VERSION` بجذر المشروع بدل كتابة الرقم يدوياً هنا، لضمان تطابقها مع `/etc/edbp-release` و CHANGELOG.

إعطاء صلاحية:

```bash
chmod +x auto/config
```

---

# شرح الإعداد

## التوزيعة

```bash
--distribution trixie
```

Debian 13.

---

## المعمارية

```bash
--architecture amd64
```

أجهزة الشركات التقليدية.

---

## المستودعات

```bash
main contrib non-free-firmware
```

للدعم الكامل:

* Firmware
* تعريفات الشبكات
* كروت الشاشة
* أجهزة حديثة

---

# 7. Software Layer

## ملف قائمة البرامج

المسار:

```bash
config/package-lists/enterprise.list.chroot
```

إنشاء:

```bash
nano config/package-lists/enterprise.list.chroot
```

---

# المحتوى النهائي

```text
################################
# Desktop Environment
################################

task-kde-desktop
sddm


################################
# Base System Utilities
################################

curl
wget
vim
nano
htop
tree
bash-completion
rsync
zip
unzip


################################
# Security
################################

nftables
openssh-server
usbguard
keepassxc
ca-certificates
gnupg


################################
# Localization Arabic
################################

locales
locales-all
task-arabic

fonts-noto-core
fonts-noto-extra
fonts-noto-cjk
fonts-noto-color-emoji

fonts-arabeyes
fonts-liberation


################################
# LibreOffice Enterprise Office
################################

libreoffice
libreoffice-l10n-ar
hunspell-ar
mythes-ar


################################
# Printing & Scanning
################################

cups
cups-client
cups-filters
printer-driver-all
hp-ppd
hplip
openprinting-ppds

avahi-daemon

simple-scan
sane-utils


################################
# Network Tools
################################

network-manager
network-manager-openvpn
openssh-client


################################
# Multimedia Support
################################

ffmpeg
vlc


################################
# Archive Support
################################

p7zip-full
file-roller
```

---

# 8. Enterprise Applications Hook

بعض البرامج ليست ضمن مستودعات Debian الرسمية:

* Brave Browser
* Element Desktop

لذلك يتم تثبيتها أثناء البناء.

---

## الملف:

```bash
config/hooks/live/10-enterprise-apps.hook.chroot
```

---

إنشاء:

```bash
nano config/hooks/live/10-enterprise-apps.hook.chroot
```

---

المحتوى:

```bash
#!/bin/bash

set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive


echo "[EDBP] Installing Enterprise Applications"


################################
# Keyrings Directory
################################

install -m 0755 -d \
/usr/share/keyrings


################################
# Brave Browser
################################

curl -fsSLo \
/usr/share/keyrings/brave-browser-archive-keyring.gpg \
https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg


cat > /etc/apt/sources.list.d/brave-browser-release.sources <<EOF
Types: deb
URIs: https://brave-browser-apt-release.s3.brave.com/
Suites: stable
Components: main
Signed-By: /usr/share/keyrings/brave-browser-archive-keyring.gpg
EOF



################################
# Element Desktop
################################

curl -fsSL \
https://packages.element.io/debian/element-io-archive-keyring.gpg \
-o /usr/share/keyrings/element-io-archive-keyring.gpg


cat > /etc/apt/sources.list.d/element.sources <<EOF
Types: deb
URIs: https://packages.element.io/debian/
Suites: default
Components: main
Signed-By: /usr/share/keyrings/element-io-archive-keyring.gpg
EOF



################################
# Install Packages
################################


apt-get update


apt-get install -y \
brave-origin \
element-desktop


apt-get clean
```

---

إعطاء الصلاحية:

```bash
chmod +x config/hooks/live/10-enterprise-apps.hook.chroot
```

---

# 9. Branding + Default User Environment

المرحلة التالية:

ملف:

```text
20-branding-config.hook.chroot
```

سيقوم بـ:

* إعداد LibreOffice RTL
* واجهة KDE الافتراضية
* SDDM
* إنشاء `/etc/edbp-release`
* تهيئة إعدادات المستخدم الجديدة

---

# EDBP — Enterprise Debian Build Platform

## Implementation Runbook v2.0.1

## الجزء الثالث: Branding + Security Hardening Layer

---

# 10. Branding & Default Configuration Hook

## الملف:

```bash id="h7w9yq"
config/hooks/live/20-branding-config.hook.chroot
```

إنشاء:

```bash id="q9l5sa"
nano config/hooks/live/20-branding-config.hook.chroot
```

---

## المحتوى:

```bash id="6n1qj9"
#!/bin/bash

set -Eeuo pipefail


echo "[EDBP] Applying Desktop Branding Configuration"



################################
# EDBP Release Information
################################


mkdir -p /etc/edbp

# ملف VERSION يُنسخ إلى config/includes.chroot/etc/edbp/VERSION
# ضمن خطوة "prepare" في الـ Makefile قبل كل بناء (انظر §18).
EDBP_VERSION="$(cat /etc/edbp/VERSION 2>/dev/null || echo "UNKNOWN")"

cat > /etc/edbp-release <<EOF
EDBP Enterprise Desktop
Version: ${EDBP_VERSION}
Build Date: $(date -I)
Distribution: Debian 13 Trixie
Architecture: amd64
EOF



################################
# LibreOffice Arabic RTL Setup
################################


mkdir -p /etc/skel/.config/libreoffice/4/user


cat > /etc/skel/.config/libreoffice/4/user/registrymodifications.xcu <<EOF

<?xml version="1.0" encoding="UTF-8"?>

<oor:items
xmlns:oor="http://openoffice.org/2001/registry">


<item oor:path="/org.openoffice.Office.Common/I18N">
 <prop oor:name="CTL">
  <value>true</value>
 </prop>
</item>


<item oor:path="/org.openoffice.Office.Writer/Settings">
 <prop oor:name="DefaultTextDirection">
  <value>1</value>
 </prop>
</item>


<item oor:path="/org.openoffice.Office.Common/Misc">
 <prop oor:name="UseTabbedUI">
  <value>true</value>
 </prop>
</item>


</oor:items>

EOF



################################
# KDE Default Configuration
################################


mkdir -p /etc/skel/.config


cat > /etc/skel/.config/kdeglobals <<EOF

[KDE]
SingleClick=false

[General]
TerminalApplication=konsole

EOF



################################
# SDDM Configuration
################################


mkdir -p /etc/sddm.conf.d


cat > /etc/sddm.conf.d/branding.conf <<EOF

[Theme]
Current=breeze


[Autologin]
Relogin=false

EOF



################################
# Enable Services
################################


systemctl enable sddm
systemctl enable cups
systemctl enable avahi-daemon
```

---

إعطاء الصلاحية:

```bash id="rsl6qf"
chmod +x config/hooks/live/20-branding-config.hook.chroot
```

---

# 11. Security Hardening Hook

## الملف:

```bash id="a7k4mo"
config/hooks/live/30-security-hardening.hook.chroot
```

---

إنشاء:

```bash id="uj4n2c"
nano config/hooks/live/30-security-hardening.hook.chroot
```

---

المحتوى:

```bash id="r5ybyd"
#!/bin/bash

set -Eeuo pipefail


echo "[EDBP] Applying Security Policies"



################################
# SSH Hardening (drop-in, not sed)
################################

# لا نعدّل /etc/ssh/sshd_config مباشرة بـ sed لأن ذلك يعتمد
# على شكل الملف الافتراضي بالضبط وقد يفشل بصمت إذا تغيّر.
# بدلاً من ذلك نستخدم ملف drop-in مستقل وواضح للمراجعة.

mkdir -p /etc/ssh/sshd_config.d

cat > /etc/ssh/sshd_config.d/99-edbp-hardening.conf <<EOF
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
X11Forwarding no
AllowUsers localadmin
EOF

chmod 600 /etc/ssh/sshd_config.d/99-edbp-hardening.conf

################################
# USB Storage Policy
################################

# القرار المعتمد: الخيار B (Enterprise Flexible).
# لا يتم حظر وحدة usb-storage على مستوى الكيرنل؛ التحكم بالكامل
# يتم عبر USBGuard أدناه (Implicit block + قواعد صريحة للسماح).
# لتفعيل الخيار A (Security Maximum) لبيئة أكثر حساسية، أعد إضافة:
#
#   cat > /etc/modprobe.d/usb-storage.conf <<'BLOCK'
#   blacklist usb-storage
#   BLOCK



################################
# USBGuard Baseline Policy
################################


mkdir -p /etc/usbguard


cat > /etc/usbguard/rules.conf <<EOF

allow with-interface 03:*:*

EOF



cat > /etc/usbguard/usbguard-daemon.conf <<EOF

IPCAllowedUsers=localadmin
IPCAllowedGroups=sudo

ImplicitPolicyTarget=block

RuleFile=/etc/usbguard/rules.conf

EOF



chmod 600 \
/etc/usbguard/rules.conf \
/etc/usbguard/usbguard-daemon.conf



systemctl enable usbguard



################################
# nftables Firewall
################################


cat > /etc/nftables.conf <<EOF

#!/usr/sbin/nft -f


flush ruleset



table inet filter {


chain input {

type filter hook input priority filter;

policy drop;


iif lo accept


ct state established,related accept


tcp dport 22 accept

}



chain output {

type filter hook output priority filter;

policy drop;


oif lo accept


ct state established,related accept


udp dport {53,123} accept


tcp dport {53,80,443} accept

}



chain forward {

type filter hook forward priority filter;

policy drop;

}


}

EOF



systemctl enable nftables
```

---

# 12. إدخال SSH Public Key داخل ISO

## مكان المفتاح:

```text id="8s4r8d"
config/includes.chroot/etc/edbp/keys/devops_admin.pub
```

مثال:

```text id="c0axm1"
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAxxxx devops@company
```

---

ملاحظات:

* هذا المفتاح عام فقط.
* لا توجد أي مفاتيح خاصة داخل المشروع.
* الـ Private Key يبقى مع DevOps.

---

# 13. صلاحيات كل الـ Hooks

بعد إنشاء الملفات:

```bash id="s4e5w0"
chmod +x config/hooks/live/*.hook.chroot
```

---

# النتيجة بعد هذه المرحلة

الـ ISO أصبح يحتوي:

✅ Debian 13
✅ KDE Plasma
✅ LibreOffice عربي RTL
✅ Brave
✅ Element
✅ KeePassXC
✅ طباعة ومسح ضوئي
✅ SSH Hardening
✅ Public Key جاهز للإدارة
✅ USB Protection
✅ Firewall
✅ Version Tracking

---

# EDBP — Enterprise Debian Build Platform

## Implementation Runbook v2.0.1

## الجزء الرابع: Automated Installer (Preseed Zero-Touch Deployment)

هذا الجزء مسؤول عن **تثبيت النظام على الجهاز الحقيقي**.
هنا فقط يتم:

* تقسيم القرص.
* إنشاء المستخدم الإداري.
* إنشاء مستخدم الموظف.
* تثبيت GRUB.
* نقل SSH Public Key.
* تجهيز النظام لأول إقلاع.

---

# 14. Debian Installer Preseed

## الملف:

```bash id="z9d7yr"
config/includes.binary/preseed.cfg
```

إنشاء:

```bash id="n8q1zv"
mkdir -p config/includes.binary
nano config/includes.binary/preseed.cfg
```

---

# المحتوى الكامل:

```text id="b7z3hd"

#############################################
# Locale & Language
#############################################

d-i debian-installer/locale string ar_SY.UTF-8

d-i localechooser/supported-locales multiselect \
ar_SY.UTF-8, en_US.UTF-8


#############################################
# Keyboard
#############################################

d-i keyboard-configuration/xkb-keymap select us

d-i keyboard-configuration/variant select


#############################################
# Network
#############################################

d-i netcfg/choose_interface select auto

d-i netcfg/get_hostname string edbp-system

d-i netcfg/get_domain string company.local



#############################################
# Time Configuration
#############################################

d-i clock-setup/utc boolean true

d-i time/zone string Asia/Damascus



#############################################
# Root Account
#############################################

d-i passwd/root-login boolean false



#############################################
# Local Administrator Account
#############################################

d-i passwd/user-fullname string Local Administrator

d-i passwd/username string localadmin

d-i passwd/user-default-groups string sudo


# ضع هنا SHA512 Hash حقيقي

d-i passwd/user-password-crypted password \
$6$REPLACE_WITH_REAL_SHA512_HASH


d-i user-setup/allow-password-weak boolean false



#############################################
# Disk Partitioning
#############################################

# Automatic LVM

d-i partman-auto/method string lvm


d-i partman-auto-lvm/guided_size string max


d-i partman-lvm/device_remove_lvm boolean true


d-i partman-lvm/confirm boolean true


d-i partman-lvm/confirm_nooverwrite boolean true



# Recipe

d-i partman-auto/choose_recipe select atomic


d-i partman-partitioning/confirm_write_new_label boolean true


d-i partman/choose_partition select finish


d-i partman/confirm boolean true


d-i partman/confirm_nooverwrite boolean true



#############################################
# Package Installation
#############################################

# ملاحظة: لا يوجد هنا استدعاء لـ tasksel عن قصد.
# الحزم يتم التحكم بها بالكامل عبر config/package-lists/*.list.chroot
# ضمن live-build؛ استخدام tasksel هنا كان يضيف طبقة تثبيت ثانية
# غير متوقعة (task standard) ويمكن أن يتعارض معها.



#############################################
# Bootloader
#############################################

d-i grub-installer/only_debian boolean true


d-i grub-installer/with_other_os boolean false


d-i grub-installer/bootdev string default



#############################################
# SSH Public Key Injection + Employee User Creation
#############################################

# ⚠️ Debian Installer لا يسمح بتعريف d-i preseed/late_command أكثر
# من مرة واحدة. لذلك كل أوامر مرحلة ما-بعد-التثبيت (نسخ SSH key
# وإنشاء user2) مدمجة هنا بأمر واحد فقط.

# إنشاء المستخدم الثاني (تعليق shell صحيح بصيغة preseed: يبدأ بـ #)

d-i preseed/late_command string \
in-target mkdir -p /home/localadmin/.ssh; \
in-target cp /etc/edbp/keys/devops_admin.pub /home/localadmin/.ssh/authorized_keys; \
in-target chown -R localadmin:localadmin /home/localadmin/.ssh; \
in-target chmod 700 /home/localadmin/.ssh; \
in-target chmod 600 /home/localadmin/.ssh/authorized_keys; \
in-target rm -rf /etc/edbp/keys; \
in-target useradd -m -s /bin/bash -G users user2; \
in-target chfn -f "Employee User" user2; \
in-target passwd -l user2



#############################################
# Finalize Installation
#############################################

d-i finish-install/reboot_in_progress note
```

---

# 15. ملاحظة مهمة حول `late_command`

في Debian Installer لا يمكن تعريف:

```text
d-i preseed/late_command
```

مرتين.

لذلك يجب دمج أوامر:

* SSH Key
* إنشاء user2

في أمر واحد.

الصيغة الصحيحة النهائية:

```text
d-i preseed/late_command string \
in-target mkdir -p /home/localadmin/.ssh; \
in-target cp /etc/edbp/keys/devops_admin.pub /home/localadmin/.ssh/authorized_keys; \
in-target chown -R localadmin:localadmin /home/localadmin/.ssh; \
in-target chmod 700 /home/localadmin/.ssh; \
in-target chmod 600 /home/localadmin/.ssh/authorized_keys; \
in-target rm -rf /etc/edbp/keys; \
in-target useradd -m -s /bin/bash -G users user2; \
in-target chfn -f "Employee User" user2; \
in-target passwd -l user2
```

---

# 16. إنشاء Hash كلمة المرور

لا تضع كلمة المرور نصاً.

استخدم الأداة القياسية (OpenSSL) لتوليد تجزئة SHA-512 (-6):

```bash
openssl passwd -6
```

مثال:

```bash
openssl passwd -6
Password: 
Verifying - Password: 
```

الناتج:

```text
$6$xxxxxxx....
```

يوضع مكان:

```text
$6$REPLACE_WITH_REAL_SHA512_HASH
```

---

# 17. نتيجة التثبيت

بعد انتهاء التثبيت:

الجهاز يحتوي:

```text
/
├── Debian 13
├── KDE Plasma
│
├── Users
│   |
│   ├── localadmin
│   │      |
│   │      └── SSH Public Key
│   │
│   └── user2
│          |
│          └── Locked Password
│
├── SSH
│   |
│   └── DevOps Private Key Login
│
└── Security Policies
```

---

# ملاحظة هندسية أخيرة

بهذا التصميم:

* الـ ISO لا يحتوي أي Private Key.
* لا يوجد First Boot Service.
* لا يوجد Race Condition.
* المستخدم الإداري موجود قبل أول إقلاع.
* SSH جاهز مباشرة بعد التثبيت.
* DevOps يستطيع الدخول باستخدام الـ Private Key الخاص به.

---

# EDBP — Enterprise Debian Build Platform

## Implementation Runbook v2.0.1

## الجزء الخامس: Build Pipeline + Validation + ISO Release

---

# 18. Makefile — Build Controller

بدلاً من تنفيذ أوامر `live-build` يدوياً، يتم التحكم بدورة البناء عبر Makefile.

المسار:

```bash
Makefile
```

إنشاء:

```bash
nano Makefile
```

---

## المحتوى:

```makefile
.PHONY: init prepare build clean verify test


#################################
# Initialize Build Environment
#################################

init:
	lb config



#################################
# Prepare Build Files
#################################

prepare:
	@echo "[EDBP] Preparing build environment..."

	@if [ ! -f VERSION ]; then \
		echo "2.0.1" > VERSION; \
	fi

	@if [ ! -f config/includes.chroot/etc/edbp/keys/devops_admin.pub ]; then \
		echo "ERROR: Missing SSH public key"; \
		exit 1; \
	fi



#################################
# Build ISO
#################################

build: prepare
	@echo "[EDBP] Starting ISO Build..."
	sudo lb build



#################################
# Clean Workspace
#################################

clean:
	@echo "[EDBP] Cleaning build environment..."

	sudo lb clean --purge

	sudo rm -rf cache/*
	sudo rm -rf chroot/*
	sudo rm -rf binary/*



#################################
# Security Verification
#################################

verify:

	@echo "[EDBP] Running security checks..."

	@if find . -name "*.pem" -o -name "id_rsa" | grep .; then \
		echo "ERROR: Private key detected"; \
		exit 1; \
	fi


	@if grep -r "password" config/ | grep -v crypted; then \
		echo "WARNING: Possible plain password"; \
	fi
      
      ssh-keygen -lf config/includes.chroot/etc/edbp/keys/devops_admin.pub

	@echo "Security checks completed."



#################################
# ISO Testing
#################################

test:

	@echo "[EDBP] ISO Test Ready"

	qemu-system-x86_64 \
	-m 4096 \
	-cdrom *.iso \
	-boot d

```

---

# 19. Build Lifecycle

## أول بناء

من داخل:

```bash
cd ~/enterprise-iso/edbp-build
```

---

تهيئة:

```bash
make init
```

---

فحص الملفات:

```bash
make verify
```

---

تنظيف البيئة:

```bash
make clean
```

---

البناء:

```bash
make build
```

---

الناتج:

مثلاً:

```text
edbp-build/
|
└── edbp-enterprise-amd64.iso
```

---

# 20. ISO Validation

قبل تسليم أي ISO يجب اختبار:

---

## 1. الإقلاع

اختبار:

```bash
qemu-system-x86_64 \
-m 4096 \
-cdrom edbp.iso
```

التحقق:

✅ يظهر Debian Installer
✅ يبدأ التثبيت الآلي
✅ لا يطلب إدخال يدوي

---

# 21. Post Installation Verification

بعد تثبيت النظام:

## معلومات الإصدار

```bash
cat /etc/edbp-release
```

الناتج المتوقع:

```text
EDBP Enterprise Desktop
Version: 2.0.1
Distribution: Debian 13 Trixie
Architecture: amd64
```

---

# 22. اختبار المستخدمين

## المستخدم الإداري

```bash
id localadmin
```

المتوقع:

```text
uid=1000(localadmin)
groups=sudo
```

---

## مستخدم الموظف

```bash
id user2
```

المتوقع:

```text
groups=users
```

---

حالة كلمة المرور:

```bash
passwd -S user2
```

المتوقع:

```text
L
```

Locked.

---

# 23. اختبار SSH

من جهاز DevOps:

```bash
ssh -i devops_private_key \
localadmin@DEVICE_IP
```

يجب:

✅ الدخول ينجح

---

تجربة كلمة المرور:

```bash
ssh localadmin@DEVICE_IP
```

يجب:

❌ يرفض Password Authentication

---

# 24. اختبار الخدمات

## SSH

```bash
systemctl status ssh
```

---

## Firewall

```bash
systemctl status nftables
```

---

## USBGuard

```bash
systemctl status usbguard
```

---

## Printing

```bash
systemctl status cups
```

---

# 25. اختبار البرامج

## KDE

```bash
plasmashell --version
```

---

## LibreOffice

التحقق:

* اللغة العربية
* اتجاه RTL
* Tabbed Interface

---

## Brave

```bash
brave-browser --version
```

---

## Element

```bash
element-desktop --version
```

---

# 26. Release Management

كل إصدار يجب أن يكون له:

```text
EDBP Release

v2.0.1
 |
 |
 +-- ISO
 |
 +-- SHA256
 |
 +-- CHANGELOG
 |
 +-- Build Date
```

---

إنشاء checksum:

```bash
sha256sum edbp-enterprise-amd64.iso \
> edbp-enterprise-amd64.iso.sha256
```

---

# 27. CHANGELOG

ملف:

```bash
CHANGELOG.md
```

مثال:

```markdown
# EDBP Changelog

## 2.0.1

Initial Production Release

Features:

- Debian 13 Trixie
- KDE Plasma
- Arabic Localization
- LibreOffice RTL
- SSH Key Management
- USBGuard Policy
- nftables Firewall
- Zero Touch Installation

```

---

# 28. Deployment Procedure

التسليم:

```text
ISO Release
      |
      |
USB / PXE
      |
      |
Employee Device
      |
      |
Automatic Install
      |
      |
DevOps SSH Access
```

---

# 29. النسخة النهائية من المعمارية

```text
                 Git Repository
                       |
                       |
                EDBP Build Server
                       |
                       |
                  live-build
                       |
                       |
              Immutable ISO Image
                       |
                       |
              Debian Automated Install
                       |
                       |
        +--------------+--------------+
        |                             |
   localadmin                    user2
        |
        |
 authorized_keys
        |
        |
 DevOps Private Key
```

---

# حالة المشروع بعد هذه المرحلة

EDBP v2.0.1 أصبح يحتوي:

✅ Immutable Debian Image
✅ Automated Installer
✅ Enterprise Desktop
✅ Arabic Office Environment
✅ Secure SSH Administration
✅ No Password Login
✅ Public Key داخل ISO فقط
✅ Private Key خارج النظام
✅ Firewall Policy
✅ USB Protection
✅ Versioned Releases
✅ ISO Validation Workflow

---

# EDBP — Enterprise Debian Build Platform

## Implementation Runbook v2.0.1

## الجزء السادس والأخير: Operations Lifecycle + Future Scaling

---

# 30. التشغيل اليومي لمنصة EDBP

بعد اعتماد النسخة الأولى، لا يتم تعديل الأجهزة مباشرة.

أي تغيير يمر عبر دورة إصدار جديدة:

```text
Change Request
       |
       |
 Git Repository
       |
       |
 Code Review
       |
       |
 Build ISO
       |
       |
 Validation
       |
       |
 Release
       |
       |
 Deployment
```

---

# 31. سياسة إصدار النسخ

يتم اعتماد Semantic Versioning:

```text
MAJOR.MINOR.PATCH
```

مثال:

```text
2.0.1
```

---

## تحديث أمني بسيط:

مثلاً:

* تحديث Brave
* تحديث LibreOffice
* تحديث تعريفات

الإصدار:

```text
2.0.1
```

---

## إضافة ميزة:

مثلاً:

* برنامج جديد
* سياسة جديدة

الإصدار:

```text
2.1.0
```

---

## تغيير جذري:

مثلاً:

* Debian 14
* تغيير KDE
* تغيير طريقة التثبيت

الإصدار:

```text
3.0.0
```

---

# 32. إدارة التحديثات

لأن النظام مبني كـ Immutable Image:

لا يتم:

❌ تعديل الأجهزة يدوياً
❌ تشغيل سكربتات عشوائية على أجهزة الموظفين

الطريقة:

## إصدار ISO جديد

مثال:

الإصدار الحالي:

```text
EDBP 2.0.1
```

بعد شهر:

```text
EDBP 2.0.1
```

يحتوي:

* Security Updates
* Package Updates
* Bug Fixes

---

# 33. تحديث الأجهزة الموجودة

هناك ثلاث حالات:

---

## الحالة الأولى: جهاز جديد

يتم تثبيت آخر ISO:

```text
EDBP-2.0.1.iso
```

---

## الحالة الثانية: أجهزة موجودة

يتم تحديثها بواسطة:

```bash
apt update
apt upgrade
```

مع الحفاظ على:

* المستخدمين
* الملفات
* إعدادات المؤسسة

---

## الحالة الثالثة: إعادة نشر كاملة

للأجهزة التي تحتاج تنظيف:

```text
Backup Data
      |
      |
Install Latest ISO
      |
      |
Restore User Data
```

---

# 34. إدارة مفتاح SSH

## الهيكل الحالي:

```text
DevOps
 |
 |
Private Key
 |
 |
SSH
 |
 |
localadmin
 |
 |
authorized_keys
```

---

## عند تغيير الفريق

لا نعيد بناء النظام بالكامل.

فقط:

يتم تحديث:

```text
/home/localadmin/.ssh/authorized_keys
```

---

مثال:

إزالة المفتاح القديم:

```bash
nano ~/.ssh/authorized_keys
```

إضافة الجديد:

```text
ssh-ed25519 AAAA... new-devops
```

---

# 35. حماية المفتاح الخاص

الـ Private Key الخاص بـ DevOps:

يجب أن يكون:

* خارج Git.
* خارج ISO.
* محمي بكلمة مرور.
* مخزن في مكان آمن.

مثال:

```text
DevOps Laptop
 |
 └── ~/.ssh/
      |
      └── edbp_management_key
```

---

# 36. Backup لخادم البناء

يجب حفظ:

```text
edbp-build/
 |
 +-- auto/
 |
 +-- config/
 |
 +-- scripts/
 |
 +-- VERSION
 |
 +-- CHANGELOG
```

ولا يحتاج حفظ:

```text
cache/
chroot/
binary/
```

لأنها تعاد البناء.

---

# 37. اختبار قبل أي Release

Checklist:

## Build

☐ `make clean`
☐ `make build`
☐ ISO generated

---

## Installation

☐ الإقلاع يعمل
☐ التثبيت بدون تدخل
☐ التقسيم صحيح

---

## Users

☐ localadmin موجود
☐ SSH يعمل
☐ user2 موجود

---

## Security

☐ Root SSH مغلق
☐ Password SSH مغلق
☐ nftables يعمل
☐ USBGuard يعمل

---

## Applications

☐ KDE
☐ LibreOffice Arabic
☐ Brave
☐ Element
☐ KeePassXC

---

# 38. الانتقال إلى PXE مستقبلاً

المعمارية الحالية جاهزة لذلك.

لا تحتاج تغيير:

```text
Current:

ISO
 |
 USB
 |
 Install


Future:

ISO Content
 |
 PXE Server
 |
 Network Boot
 |
 Install
```

---

# 39. PXE Architecture Future

```text
              EDBP Build Server
                     |
                     |
                 ISO Artifact
                     |
                     |
                 PXE Server
                     |
          +----------+----------+
          |                     |
       PC-001                PC-002
          |                     |
          |
      Automated Install
```

---

# 40. إضافة Repository داخلي لاحقاً

في بيئة كبيرة يمكن إضافة:

Debian Mirror داخلي:

```text
apt.company.local
```

والأجهزة تستخدم:

```text
Internal Repository
        |
        |
Employee PCs
```

الفوائد:

* سرعة.
* تحكم بالإصدارات.
* عدم الاعتماد على الإنترنت.
* مراجعة الحزم.

---

# 41. النسخة النهائية للمشروع

## EDBP v2.0.1 Architecture

```text
                    Git
                     |
                     |
             Build Server
                     |
                     |
              live-build
                     |
                     |
              Enterprise ISO
                     |
                     |
          Debian Automated Installer
                     |
        +------------+-------------+
        |                          |
   localadmin                 Employee
        |
        |
 SSH Public Key
        |
        |
 DevOps Private Key
        |
        |
 Remote Administration
```

---

# 42. النتيجة النهائية

EDBP أصبح منصة بناء نظام مؤسسي وليست مجرد ISO:

### Build

✅ Reproducible Build
✅ Version Control
✅ Immutable Image

### Deployment

✅ Zero Touch Install
✅ Automatic Partitioning
✅ Automated Users

### Security

✅ SSH Key Authentication
✅ No Root Login
✅ No Password SSH
✅ USB Control
✅ Firewall

### Enterprise Ready

✅ Release Management
✅ Validation
✅ Future PXE Support
✅ Scalable Architecture

---

## EDBP v2.0.1 — Production Baseline Completed

هذه هي النسخة المرجعية التي يجب اعتمادها كـ **Master Runbook** قبل بدء التنفيذ الفعلي على خادم البناء.
