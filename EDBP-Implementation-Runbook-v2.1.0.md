Markdown
# EDBP — Enterprise Debian Build Platform
# Implementation Runbook v2.0.2 — Production Hardened Baseline

**Status:** Production Ready Baseline (Gold Standard)  
**Target OS:** Debian 13 Trixie amd64  
**Architecture:** x86_64  
**Build Framework:** live-build  
**Installer:** Debian Installer (Zero-Touch Automated Preseed)  
**Desktop Environment:** KDE Plasma 6  
**Deployment Model:** Immutable ISO → Zero-Touch Automated Deployment  
**Remote Management:** SSH Public Key Authentication  
**Disk Encryption:** Not enabled — accepted risk per Cybersecurity Governance  

---

## 0. Executive Summary & Changelog

### سجل التعديلات المعمارية المصححة (v2.0.2-baseline)
* **معمارية الـ Installer:** الاعتماد الحصري على `--debian-installer live` في `auto/config` لتضمين الـ udeb المناسب تلقائياً، وتجريد `package-lists` من حزم الـ installer.
* **إصلاح جدار الحماية (`nftables`):** تصحيح صياغة قواعد الـ DHCP إلى `udp sport 67 udp dport 68 accept` والـ DNS إلى Port 53 لضمان استقرار الاتصال الشبكي.
* **معيارية مستودعات الطرف الثالث:** وضع مستودعات Brave و Element في `config/archives/` واستخدام المفاتيح الثنائية `.key.chroot.gpg`.
* **تأمين التثبيت المسبق (Preseed):** إزالة حقول الإدخال الفارغة وحصر عمليات ما بعد التثبيت في كتلة `late_command` ذرية واحدة.
* **أتمتة دورة الحياة (Makefile & .gitignore):** إضافة هدف `make release` لحساب التجزئة تلقائياً، وتضمين توجيه المنافذ `hostfwd=tcp::2222-:22` في QEMU، وحظر تسريب المفاتيح الخاصة.

---

## 1. Build Host Preparation

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y \
    live-build debootstrap squashfs-tools xorriso \
    grub-pc-bin grub-efi-amd64-bin mtools git make \
    shellcheck shfmt jq curl ca-certificates gnupg

sudo useradd -m -s /bin/bash builder
sudo usermod -aG sudo builder
sudo su - builder
2. Project Directory Structure
Plaintext
edbp-build/
├── .gitignore
├── auto/
│   └── config
├── config/
│   ├── archives/
│   │   ├── brave-browser.list.chroot
│   │   ├── brave-browser.key.chroot.gpg
│   │   ├── element.list.chroot
│   │   └── element.key.chroot.gpg
│   ├── hooks/
│   │   └── live/
│   │       ├── 20-branding-config.hook.chroot
│   │       └── 30-security-hardening.hook.chroot
│   ├── includes.binary/
│   │   └── preseed.cfg
│   ├── includes.chroot/
│   │   └── etc/
│   │       └── edbp/
│   │           └── keys/
│   │               └── devops_admin.pub
│   └── package-lists/
│       └── enterprise.list.chroot
├── Makefile
├── VERSION
└── CHANGELOG.md
3. Configuration Files & Source Code
3.1. .gitignore
Plaintext
# Build Artifacts
cache/
chroot/
binary/
*.iso
*.iso.sha256
*.iso.zsync

# Secrets & Keys
secrets/
*.pem
*.key
id_rsa*
id_ed25519*
id_ecdsa*
*.asc
*.gpg
!config/archives/*.key.chroot.gpg
!config/includes.chroot/etc/edbp/keys/*.pub

# OS & Temp
.DS_Store
*.swp
*.swo
*~
3.2. VERSION
Plaintext
2.0.2
3.3. auto/config
Bash
#!/bin/sh
set -e

EDBP_VERSION="$(cat ../VERSION 2>/dev/null || cat VERSION 2>/dev/null || echo "2.0.2")"

lb config noauto \
    --distribution trixie \
    --architecture amd64 \
    --archive-areas "main contrib non-free non-free-firmware" \
    --debian-installer live \
    --debian-installer-gui true \
    --iso-application "EDBP Enterprise Desktop" \
    --iso-publisher "Enterprise IT Department" \
    --iso-volume "EDBP_${EDBP_VERSION}" \
    --bootappend-live "boot=live components quiet splash" \
    --bootappend-install "auto=true priority=critical preseed/file=/cdrom/preseed.cfg quiet" \
    "${@}"
الصلاحيات: chmod +x auto/config

3.4. مستودعات الطرف الثالث ومفاتيح التحقق
Bash
# مستودع ومفتاح Brave
echo "deb [https://brave-browser-apt-release.s3.brave.com/](https://brave-browser-apt-release.s3.brave.com/) stable main" > config/archives/brave-browser.list.chroot
curl -fsSL [https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg](https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg) > config/archives/brave-browser.key.chroot.gpg

# مستودع ومفتاح Element
echo "deb [https://packages.element.io/debian/](https://packages.element.io/debian/) default main" > config/archives/element.list.chroot
curl -fsSL [https://packages.element.io/debian/element-io-archive-keyring.gpg](https://packages.element.io/debian/element-io-archive-keyring.gpg) > config/archives/element.key.chroot.gpg
3.5. config/package-lists/enterprise.list.chroot
Plaintext
# Desktop Environment & Display Manager
task-kde-desktop
sddm

# Base System Utilities
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

# Security & Management
nftables
openssh-server
openssh-client
usbguard
keepassxc
ca-certificates
gnupg

# Third-Party Enterprise Apps
brave-browser
element-desktop

# Arabic Localization & System Fonts
locales
locales-all
task-arabic
fonts-noto-core
fonts-noto-extra
fonts-noto-cjk
fonts-noto-color-emoji
fonts-arabeyes
fonts-liberation

# Productivity (LibreOffice Suite)
libreoffice
libreoffice-l10n-ar
hunspell-ar
mythes-ar

# Printing & Hardware Scanning
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

# Networking & Archival Tools
network-manager
network-manager-openvpn
ffmpeg
vlc
p7zip-full
file-roller
3.6. config/hooks/live/20-branding-config.hook.chroot
Bash
#!/bin/bash
set -Eeuo pipefail

echo "[EDBP] Applying Desktop Branding Configuration"

# Release tracking
mkdir -p /etc/edbp
EDBP_VERSION="$(cat /etc/edbp/VERSION 2>/dev/null || echo "2.0.2")"

cat > /etc/edbp-release <<EOF # $(date ${EDBP_VERSION} -I) -p /etc/skel/.config/libreoffice/4/user 13 Architecture: Build Date: Debian Desktop Distribution: EDBP EOF Enterprise LibreOffice RTL Setup Trixie Version: amd64 cat mkdir> /etc/skel/.config/libreoffice/4/user/registrymodifications.xcu <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<oor:items xmlns:oor="[http://openoffice.org/2001/registry](http://openoffice.org/2001/registry)">
 <item oor:path="/org.openoffice.Office.Common/I18N"><prop oor:name="CTL"><value>true</value></prop></item>
 <item oor:path="/org.openoffice.Office.Common/Misc"><prop oor:name="UseTabbedUI"><value>true</value></prop></item>
</oor:items>
EOF

# KDE Defaults
mkdir -p /etc/skel/.config
cat > /etc/skel/.config/kdeglobals <<EOF # -p /etc/sddm.conf.d Configuration EOF SDDM SingleClick="false" TerminalApplication="konsole" [General] [KDE] cat mkdir> /etc/sddm.conf.d/branding.conf <<EOF "[EDBP] # #!/bin/bash ### *الصلاحيات:* +x --- -Eeuo -p /etc/ssh/sshd_config.d 1. 3.7. Applying Current="breeze" EOF Enable Hardening NetworkManager Policies" Relogin="false" SSH Security Services [Autologin] [Theme] ``` ```bash `chmod `config/hooks/live/30-security-hardening.hook.chroot` avahi-daemon cat config/hooks/live/20-branding-config.hook.chroot` cups echo enable mkdir pipefail sddm set systemctl> /etc/ssh/sshd_config.d/99-edbp-hardening.conf <<EOF # -p /etc/ssh/sshd_config.d/99-edbp-hardening.conf /etc/usbguard 2. 600 AllowUsers EOF PasswordAuthentication PermitEmptyPasswords PermitRootLogin Policy PubkeyAuthentication USBGuard X11Forwarding cat chmod localadmin mkdir no yes> /etc/usbguard/rules.conf <<EOF 03:*:* EOF allow cat with-interface> /etc/usbguard/usbguard-daemon.conf <<EOF # /etc/usbguard/rules.conf /etc/usbguard/usbguard-daemon.conf 3. 600 EOF Firewall IPCAllowedGroups="sudo" IPCAllowedUsers="localadmin" ImplicitPolicyTarget="block" RuleFile="/etc/usbguard/rules.conf" cat chmod enable nftables systemctl usbguard> /etc/nftables.conf <<'EOF'
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    set local_ranges {
        type ipv4_addr
        flags interval
        elements = { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16 }
    }

    chain input {
        type filter hook input priority filter; policy drop;

        iif "lo" accept
        ct state established,related accept

        # DHCP Client responses
        udp sport 67 udp dport 68 accept

        # Authorized LAN traffic
        ip saddr @local_ranges accept
        icmp type { echo-request, echo-reply } accept
    }

    chain output {
        type filter hook output priority filter; policy drop;

        oif "lo" accept
        ct state established,related accept

        # DHCP Client requests
        udp sport 68 udp dport 67 accept

        # Outbound LAN traffic
        ip daddr @local_ranges accept

        # DNS resolution
        udp dport 53 accept
        tcp dport 53 accept
    }

    chain forward {
        type filter hook forward priority filter; policy drop;
    }
}
EOF
systemctl enable nftables
الصلاحيات: chmod +x config/hooks/live/30-security-hardening.hook.chroot

3.8. config/includes.binary/preseed.cfg
Plaintext
# Localization & Keyboard
d-i debian-installer/locale string ar_SY.UTF-8
d-i localechooser/supported-locales multiselect ar_SY.UTF-8, en_US.UTF-8
d-i keyboard-configuration/xkb-keymap select us

# Network
d-i netcfg/choose_interface select auto
d-i netcfg/get_hostname string edbp-system
d-i netcfg/get_domain string company.local

# Clock & Timezone
d-i clock-setup/utc boolean true
d-i time/zone string Asia/Damascus

# Accounts
d-i passwd/root-login boolean false
d-i passwd/user-fullname string Local Administrator
d-i passwd/username string localadmin
d-i passwd/user-default-groups string sudo
d-i passwd/user-password-crypted password $6$REPLACE_WITH_REAL_SHA512_HASH
d-i user-setup/allow-password-weak boolean false

# Partitioning
d-i partman-auto/method string lvm
d-i partman-auto-lvm/guided_size string max
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-lvm/confirm boolean true
d-i partman-lvm/confirm_nooverwrite boolean true
d-i partman-auto/choose_recipe select atomic
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true

# Bootloader
d-i grub-installer/only_debian boolean true
d-i grub-installer/with_other_os boolean false
d-i grub-installer/bootdev string default

# Single late_command execution
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

d-i finish-install/reboot_in_progress note
3.9. Makefile
(مبني مع علامات الجدولة الإلزامية Tabs)

Makefile
.PHONY: init prepare build clean verify test release

SHELL := /bin/bash

init:
	lb config

prepare:
	@echo "[EDBP] Preparing build workspace..."
	@if [ ! -f VERSION ]; then \
		echo "2.0.2" > VERSION; \
	fi
	@mkdir -p config/includes.chroot/etc/edbp
	@cp VERSION config/includes.chroot/etc/edbp/VERSION
	@if [ ! -f config/includes.chroot/etc/edbp/keys/devops_admin.pub ]; then \
		echo "ERROR: Missing SSH Public Key at config/includes.chroot/etc/edbp/keys/devops_admin.pub"; \
		exit 1; \
	fi

build: prepare
	@echo "[EDBP] Starting ISO build pipeline..."
	sudo lb build

clean:
	@echo "[EDBP] Purging build environment..."
	sudo lb clean --purge
	sudo rm -rf cache/* chroot/* binary/*

verify:
	@echo "[EDBP] Running pre-build security checks..."
	@if find . -name "*.pem" -o -name "id_rsa" -o -name "*_key" | grep -v "keyring" | grep -v "key.chroot" | grep .; then \
		echo "ERROR: Private key detected in repository!"; \
		exit 1; \
	fi
	@if grep -rn "password" config/ | grep -v "crypted" | grep -v "user-password"; then \
		echo "WARNING: Possible plaintext password in config files!"; \
	fi
	@ssh-keygen -lf config/includes.chroot/etc/edbp/keys/devops_admin.pub
	@echo "[+] Verification successful."

release: build
	@echo "[EDBP] Generating SHA256 checksum for release..."
	@iso="$$(ls -1t *.iso 2>/dev/null | head -n 1)"; \
	if [ -z "$$iso" ]; then echo "ERROR: No ISO artifact found"; exit 1; fi; \
	sha256sum "$$iso" > "$$iso.sha256"; \
	echo "[✓] Release artifact ready: $$iso"; \
	echo "[✓] Checksum written to: $$iso.sha256"

test:
	@echo "[EDBP] Launching QEMU VM test with port forwarding (2222 -> 22)..."
	qemu-system-x86_64 \
		-m 4096 \
		-smp 2 \
		-enable-kvm \
		-nic user,hostfwd=tcp::2222-:22 \
		-cdrom live-image-amd64.hybrid.iso \
		-boot d
4. Production Execution Lifecycle
Bash
# 1. حقن المفتاح العام الحقيقي
mkdir -p config/includes.chroot/etc/edbp/keys/
cp ~/.ssh/id_ed25519.pub config/includes.chroot/etc/edbp/keys/devops_admin.pub

# 2. توليد تجزئة كلمة المرور لحساب localadmin وحقنها في Preseed
HASH=$(openssl passwd -6)
sed -i "s|\$6\$REPLACE_WITH_REAL_SHA512_HASH|${HASH}|g" config/includes.binary/preseed.cfg

# 3. التهيئة والتحقق
make init
make verify

# 4. بناء وتوقيع النسخة النهائية
make release

# 5. اختبار الدخول عن بعد (أثناء تشغيل make test)
ssh -i ~/.ssh/id_ed25519 -p 2222 localadmin@localhost
