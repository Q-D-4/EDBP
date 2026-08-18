# EDBP - Enterprise Debian Build Platform

منصة بناء Debian 13 Trixie مؤسسية لمحطات عمل KDE، بآيزو UEFI هجين يحتوي
Live environment وDebian Installer تفاعلياً آمناً.

المصدر التنفيذي الوحيد للمعمارية وإجراءات البناء والقبول هو:

- [EDBP v2.2.0 Specification](./EDBP-v2.2.0-SPECIFICATION.md)

الحالة الحالية هي **Release Candidate** وليست Golden Master تلقائياً. يلزم
اجتياز بوابات P0 الموثقة، وأهمها بناء ISO فعلي، تثبيتان UEFI مستقلان، اختبار
العتاد، واعتماد معالجة DHCP/multicast في ملف nftables.

## Quick start

```bash
sudo apt install live-build debootstrap squashfs-tools xorriso \
    grub-efi-amd64-bin shim-signed mtools dosfstools \
    make git jq openssh-client sudo shellcheck \
    debconf-utils python3 ca-certificates

mkdir -p secrets
ssh-keygen -t ed25519 -f secrets/edbp_admin -C edbp-admin
cp secrets/edbp_admin.pub secrets/localadmin_authorized_keys

make verify
make all
```

لا تُضمّن المفاتيح الخاصة أو كلمة مرور مشتركة داخل المشروع أو ISO. يطلب
Debian Installer كلمة مرور فريدة لـ`localadmin`، ويُحقن المفتاح العام فقط من
`secrets/localadmin_authorized_keys` أثناء البناء.
