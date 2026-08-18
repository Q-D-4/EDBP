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
    debconf-utils python3 ca-certificates whois

install -d -m 0700 secrets
ssh-keygen -t ed25519 -f secrets/edbp_admin -C edbp-admin
cp secrets/edbp_admin.pub secrets/localadmin_authorized_keys
mkpasswd --method=yescrypt > secrets/localadmin_password_hash
chmod 0600 secrets/localadmin_authorized_keys \
    secrets/localadmin_password_hash

make verify
make all
```

لا تمرر كلمة المرور الصريحة كوسيط لسطر الأوامر. `mkpasswd` يطلبها تفاعلياً،
والمشروع يقرأ فقط crypt(3) hash من الملف المحلي غير المتتبع. يُولّد
`config/includes.installer/preseed.cfg` وقت البناء ثم يُحذف تلقائياً مع ملف
المفتاح المرحلي بعد `lb build`.

هذه آلية انتقالية وليست خزنة أسرار: الهاش مضمّن في initrd ويمكن استخراجه من
الـISO ومحاولة كسره دون اتصال. كلمة واحدة لـ600 جهاز تعني أن كشفها على جهاز
واحد يعرّض الأسطول كله؛ يجب تدويرها وإلغاء الاعتماد عليها فور اكتمال إدارة
SSH. لفحص المصدر فقط دون ملف هاش حقيقي استخدم `make verify-test`؛ هذا الهدف
لا يستطيع تشغيل `config` أو `build`.
