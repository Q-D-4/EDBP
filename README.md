# EDBP — دليل البناء والتثبيت

هذا الدليل يشرح المسار الكامل لبناء صورة EDBP وكتابتها على USB وتثبيتها. ابدأ من الأعلى واتبع الخطوات بالترتيب. الأوامر والمسارات وأسماء الحزم مكتوبة بالإنجليزية كما تظهر في النظام.

للتصميم الفني التفصيلي وبوابات القبول، راجع [EDBP v2.2.0 Specification](./EDBP-v2.2.0-SPECIFICATION.md).

> **تنبيه:** المشروع موجّه إلى نشر مؤسسي مضبوط. جرّب الـISO على جهاز اختبار قبل استخدامه على جهاز إنتاجي، ولا تعتبر البناء جاهزًا للإصدار قبل اجتياز اختبارات التثبيت الفعلية المذكورة في مواصفات المشروع.

## 1. ما هو مشروع EDBP؟

EDBP اختصار لـ **Enterprise Debian Build Platform**. يبني المشروع ملف ISO مخصصًا لمحطات عمل مؤسسية مبنيًا على Debian 13 **Trixie** لمعمارية `amd64`، مع سطح المكتب KDE Plasma 6.

يمكن الإقلاع من الـISO بطريقتين:

- تشغيل بيئة **Live** لتجربة العتاد وسطح المكتب دون تثبيت.
- تشغيل Debian Installer لتثبيت النظام على قرص الجهاز.

أثناء التثبيت ينشأ حساب فني اسمه `localadmin`. وعند أول إقلاع من القرص يشغّل النظام إعداد OOBE لإنشاء اسم الجهاز وحساب المستخدم اليومي العادي. التثبيت نفسه مصمم ليكتمل من محتوى الـISO دون مستودع APT على الشبكة.

السياسات الأمنية الأساسية تشمل جدار `nftables` بوضع LAN معزول، وUSBGuard، وتعطيل Bluetooth، وSSH بمفتاح عام لحساب `localadmin` فقط. التقسيم يبقى تفاعليًا حتى يختار الفني القرص والخطة ويؤكد الكتابة بنفسه.

## 2. المتطلبات قبل البدء

ابنِ المشروع على جهاز أو آلة افتراضية تعمل بـDebian 13 Trixie `amd64`. يحتاج البناء إلى اتصال إنترنت لتنزيل حزم Debian وحزم الموردين؛ هذا لا يعني أن التثبيت على الجهاز الهدف يحتاج إلى الإنترنت.

استخدم حساب مستخدم عادي يستطيع تشغيل `sudo`. وتأكد من وجود مساحة حرة واسعة على نظام الملفات الذي سيحتوي المستودع، لأن `live-build` ينشئ نظام Debian كاملًا ثم يضغطه في ISO. يختلف الاستهلاك حسب نسخ الحزم والكاش، لذلك افحص المساحة قبل البدء:

```bash
df -h .
```

ثبّت أدوات البناء بهذه الأوامر:

```bash
sudo apt update
sudo apt install --yes \
    live-build debootstrap squashfs-tools xorriso \
    grub-efi-amd64-bin shim-signed mtools dosfstools \
    make git jq openssh-client sudo shellcheck \
    debconf python3 ca-certificates whois
```

هذه القائمة تغطي `live-build` وأدوات ISO وUEFI، إضافة إلى الأدوات التي يفحصها `scripts/verify-tree`. أدوات Debian الأساسية مثل `bash` و`awk` و`sha256sum` و`stat` موجودة في تثبيت Trixie القياسي. بعض علاقات الأوامر بالحزم المهمة:

| الأمر | حزمة Debian Trixie |
|---|---|
| `lb` | `live-build` |
| `debconf-set-selections` | `debconf` |
| `shellcheck` | `shellcheck` |
| `ssh-keygen` | `openssh-client` |
| `/usr/sbin/visudo` | `sudo` |
| `mkpasswd` | `whois` |
| `jq` | `jq` |

## 3. تنزيل المشروع

الأمر الأول ينسخ المستودع المنشور من GitHub. الأمر الثاني ينقلك إلى مجلد المشروع:

```bash
git clone https://github.com/Q-D-4/EDBP.git
cd EDBP
```

يستخدم `git clone` الفرع الافتراضي المنشور للمشروع. للبناء الإنتاجي استخدم الفرع المعتمد لدى فريق الإصدار فقط، ولا تبدّل إلى فرع تجريبي أو تدمج تغييرات غير مراجعة.

تحقق من مكانك ومن أن الشجرة نظيفة:

```bash
pwd
git status --short --branch
```

يجب ألا يعرض `git status --short` ملفات معدلة أو غير متتبعة قبل بناء إصدار إنتاجي.

## 4. مجلد `secrets` — شرح كامل للمبتدئ

يحتاج البناء إلى مدخلين محليين لحساب `localadmin`:

- hash لكلمة مرور تسجيل الدخول المحلي و`sudo`.
- مفتاح SSH عام يسمح للإدارة عن بعد.

توضع هذه المدخلات في `secrets/`. يتجاهل Git هذا المجلد عبر `.gitignore`، لكن التجاهل ليس خزنة أسرار ولا بديلًا عن الحماية. لا تنسخ المجلد إلى مكان عام، ولا تضفه إلى Git بالقوة، ولا ترسله مع الـISO.

أنشئ المجلد واجعل الوصول إليه لصاحبه فقط:

```bash
mkdir -p secrets
chmod 700 secrets
```

### 4.1 إنشاء hash كلمة مرور `localadmin`

المسار المطلوب هو:

```text
secrets/localadmin_password_hash
```

هذا الملف **لا يحتوي كلمة المرور الصريحة**. يحتوي تمثيل `crypt(3)` مملحًا تستخدمه Debian للتحقق من كلمة المرور. يقبل المشروع حاليًا:

- `yescrypt` الذي يبدأ بـ`$y$`، وهو الخيار الموصى به هنا.
- `SHA-512-crypt` الذي يبدأ بـ`$6$`.

لا تكتب كلمة المرور داخل أمر في سطر الطرفية، لأن ذلك قد يحفظها في history أو يعرضها في قائمة العمليات. أداة `mkpasswd` من حزمة `whois` تطلبها تفاعليًا دون إظهارها على الشاشة:

```bash
sudo apt install --yes whois
( umask 077; mkpasswd --method=yescrypt > secrets/localadmin_password_hash )
chmod 600 secrets/localadmin_password_hash
```

عند ظهور مطالبة `Password:` أدخل كلمة مرور إنتاجية قوية وعشوائية وفق سياسة مؤسستك. لا تستخدم اسم المؤسسة أو موسمًا أو تسلسلًا متوقعًا. لا يعرض الطرفية الأحرف أثناء الكتابة، وهذا طبيعي.

تحقق من وجود الملف وملكيته وصلاحياته دون طباعة محتواه:

```bash
stat -c 'file=%n owner=%U:%G mode=%a bytes=%s' \
    secrets/localadmin_password_hash
```

يجب أن تكون `mode=600`، وأن يملك الملف مستخدم البناء الحالي. يرفض المشروع symlink، أو ملفًا قابلًا للقراءة من مستخدمين آخرين، أو أكثر من سجل واحد، أو خوارزمية غير مدعومة.

> **مهم:** يمكن استخراج hash من initrd داخل الـISO ومحاولة تخمين كلمة المرور دون اتصال. استخدم كلمة مرور قوية، احمِ ملف الـISO، ودوّر كلمة المرور وفق سياسة الاعتماد. لا تنشر hash حتى لو لم يكن كلمة المرور الصريحة.

### 4.2 إنشاء مفتاح SSH لحساب `localadmin`

مفتاح SSH زوج من ملفين:

- **المفتاح الخاص** يثبت هوية المسؤول. يبقى مع المسؤول فقط، ويفضل حمايته بعبارة مرور. لا يدخل المستودع ولا مجلد `secrets` ولا الـISO مطلقًا.
- **المفتاح العام** ينتهي عادةً بـ`.pub`. يمكن وضعه في مدخل البناء ليصبح سطرًا داخل `authorized_keys` لحساب `localadmin`.

أنشئ زوج Ed25519 في مجلد SSH الشخصي، خارج المستودع:

```bash
install -d -m 700 "$HOME/.ssh"
ssh-keygen -t ed25519 -a 100 \
    -f "$HOME/.ssh/edbp_localadmin_ed25519" \
    -C "edbp-localadmin"
```

يسألك `ssh-keygen` عن عبارة مرور للمفتاح الخاص. استخدم عبارة قوية واحفظها في مدير الاعتمادات المعتمد. تركها فارغة يعني أن سرقة الملف الخاص قد تكفي لتسجيل الدخول.

ينشئ الأمر ملفين:

```text
$HOME/.ssh/edbp_localadmin_ed25519       ← PRIVATE: لا تنسخه إلى المشروع
$HOME/.ssh/edbp_localadmin_ed25519.pub   ← PUBLIC: هذا الذي يسمح بنسخه
```

انسخ **الملف العام فقط** إلى المسار الذي ينتظره البناء:

```bash
install -m 600 \
    "$HOME/.ssh/edbp_localadmin_ed25519.pub" \
    secrets/localadmin_authorized_keys
```

تحقق من نوع المفتاح العام وبصمته، ثم تحقق من صلاحية ملف البناء:

```bash
ssh-keygen -lf "$HOME/.ssh/edbp_localadmin_ed25519.pub"
stat -c 'file=%n owner=%U:%G mode=%a bytes=%s' \
    secrets/localadmin_authorized_keys
```

يقبل `scripts/stage-admin-keys` مفاتيح `ssh-ed25519` و`sk-ssh-ed25519@openssh.com` الصحيحة فقط، بحد أقصى 20 مفتاحًا. يتجاهل الأسطر الفارغة والتعليقات. بعد التثبيت يضع النظام المفاتيح العامة المقبولة في `/home/localadmin/.ssh/authorized_keys`، بينما يولد لكل جهاز مفاتيح SSH host فريدة.

> **تحذير حاسم:** لا تنسخ `$HOME/.ssh/edbp_localadmin_ed25519` إلى `secrets/`. لا ترفعه إلى GitHub، ولا ترسله إلى جهاز الهدف. الملف المسموح به في مدخل البناء هو الملف الذي ينتهي بـ`.pub` فقط.

## 5. التحقق من ملفات `secrets`

نفّذ الفحص التالي من جذر المستودع. لا يطبع هذا الفحص hash كلمة المرور ولا محتوى المفاتيح:

```bash
test -d secrets
test -f secrets/localadmin_password_hash
test ! -L secrets/localadmin_password_hash
test -f secrets/localadmin_authorized_keys
test ! -L secrets/localadmin_authorized_keys

stat -c 'file=%n owner=%U:%G mode=%a bytes=%s' \
    secrets/localadmin_password_hash \
    secrets/localadmin_authorized_keys

test -z "$(git ls-files -- \
    secrets/localadmin_password_hash \
    secrets/localadmin_authorized_keys)"
git check-ignore -v \
    secrets/localadmin_password_hash \
    secrets/localadmin_authorized_keys
git status --short
```

النتيجة الصحيحة هي:

- كلا الملفين موجودان و`mode=600`.
- يعرض `git check-ignore` قاعدة `.gitignore` لكل مسار.
- لا يعرض `git status --short` ملفات `secrets`، ولا يعرض أي تغيير آخر في بناء إنتاجي نظيف.

إذا أظهر Git أحد الملفين كملف متتبع، توقف ولا تبنِ. لا تستخدم `git add -f` مع `secrets/`.

## 6. فحص المشروع قبل البناء

شغّل:

```bash
make verify
```

هذا الأمر **لا يبني ISO**. يفحص نظافة Git، والأوامر المطلوبة على جهاز البناء، وصياغة shell، وShellCheck، وسياسات installer وUEFI وAPT وOOBE وPlasma والأمان، ثم يتحقق من ملفي `secrets` ويولد نسخة preseed مؤقتة للتحقق فقط.

يعني انتهاء الأمر دون `ERROR` أن بوابة المصدر اجتازت، لا أن ISO بُني أو اجتاز اختبار عتاد.

أخطاء شائعة في هذه المرحلة:

- `required build-host command is missing: shellcheck`: ثبّت `shellcheck` بواسطة `sudo apt install --yes shellcheck`.
- `required build-host command is missing: /usr/sbin/visudo`: ثبّت حزمة `sudo`. لا تحتاج إلى تعديل `PATH`.
- `admin key source must be...` أو `no SSH public keys...`: أنشئ `secrets/localadmin_authorized_keys` من المفتاح العام فقط وأعد `chmod 600`.
- `localadmin password hash file is missing`: أنشئ `secrets/localadmin_password_hash` بالطريقة التفاعلية في القسم 4.1.
- خطأ ملكية أو صلاحيات لملف hash: شغّل `chmod 600` وتأكد أن مستخدم البناء يملك الملف وأن `secrets/` ليس قابلًا للكتابة من المجموعة أو الآخرين.
- `source tree is dirty`: افحص `git status --short` وراجع كل تغيير. التزم بالتغييرات المقصودة أو أعدها بطريقة واعية قبل البناء؛ لا تحذفها عشوائيًا.

يوجد `make verify-test` لاختبارات المصدر الآلية حين لا يتوفر hash إنتاجي، لكنه يستخدم hash اصطناعيًا مؤقتًا ولا يمكنه تهيئة أو بناء ISO. لا تستخدمه بدل `make verify` لبناء إنتاجي.

## 7. تنظيف بناء سابق

قبل بناء جديد نظف حالة `live-build` والمخرجات القديمة:

```bash
make clean
```

يحذف هذا الهدف حالة البناء والـISO القديم وملفات manifest وchecksum والمدخلات المرحلية المولدة. لا يحذف ملفات المصدر داخل `secrets/`.

> **تحذير:** لا تستخدم `git clean -fdx`. الخيار `-x` يحذف الملفات المتجاهلة، وقد يمحو مجلد `secrets/` ومدخلات الاعتماد المحلية غير القابلة للاستعادة.

بعد التنظيف تحقق مرة أخرى:

```bash
git status --short
make verify
```

## 8. بناء الـISO

ابدأ البناء الإنتاجي من شجرة نظيفة وبعد نجاح `make verify`:

```bash
make all
```

ينفذ الهدف، بصورة مفاهيمية، الخطوات التالية:

1. يعيد التحقق من المصدر والمدخلات.
2. ينشئ نسخة مرحلية من المفاتيح العامة المقبولة ويحقن hash في preseed مرحلي بصلاحيات ضيقة.
3. يشغّل `lb config` ثم `lb build`، ويطلب `sudo` عند الحاجة.
4. يحذف preseed وملف `authorized_keys` المرحليين عند النجاح أو الفشل أو المقاطعة. تبقى ملفات المصدر داخل `secrets/` تحت مسؤولية المشغل.
5. يولد `SHA256SUMS` وملف الحزم وبيانات provenance وmanifest، ثم يعيد التحقق من checksums.

قد يستغرق البناء وقتًا طويلًا ويحتاج إلى تنزيلات كثيرة. لا تغلق الطرفية ولا تفصل الشبكة أو التخزين أثناءه.

يشتق Makefile اسم الصورة من `VERSION`. الإصدار الحالي `2.2.0`، لذلك اسم الـISO المتوقع هو:

```text
edbp-2.2.0-amd64.hybrid.iso
```

اعرض الإصدار الفعلي وابحث عن ناتج البناء دون افتراض أن الرقم سيبقى ثابتًا مستقبلًا:

```bash
printf 'VERSION=' && sed -n '1p' VERSION
ls -lh edbp-*-amd64.hybrid.iso
sha256sum --check --strict SHA256SUMS
```

تشمل المخرجات المعتادة أيضًا ملف `.packages` و`.build-inputs.json` و`.manifest.json` و`build.log`.

## 9. نسخ الـISO إلى USB

كتابة ISO على USB تمحو **كل محتوى الجهاز المحدد**، بما في ذلك جدول الأقسام. الطريقة الأقل عرضة للخطأ للمبتدئ هي استخدام أداة رسومية موثوقة مثل KDE ISO Image Writer أو GNOME Disks: اختر ملف `edbp-*-amd64.hybrid.iso`، ثم راجع اسم الشركة والطراز والسعة لجهاز USB قبل الضغط على Write.

إذا كان لا بد من استخدام `dd`، ابدأ بعرض الأقراص:

```bash
lsblk -o NAME,PATH,SIZE,MODEL,SERIAL,TRAN,TYPE,MOUNTPOINTS
ls -l /dev/disk/by-id/usb-* 2>/dev/null
```

تعرف إلى USB بواسطة `MODEL` و`SERIAL` و`SIZE`. افصل الجهاز وأعد توصيله إن لم تكن متأكدًا أي سطر يخصه. افصل أقسام USB المركبة من مدير الملفات، ثم أعد `lsblk` وتأكد أن `MOUNTPOINTS` فارغ.

الجهاز الكامل يكون مثل `/dev/sdX` أو رابط `/dev/disk/by-id/usb-...`. القسم مثل `/dev/sdX1` أو رابط ينتهي بـ`-part1`. يجب أن تكون وجهة الكتابة **الجهاز الكامل لا القسم**.

اضبط المتغير التالي يدويًا على رابط `by-id` الدقيق الذي راجعته. القيمة الافتراضية المقصودة في المثال غير موجودة، لذلك يفشل الفحص بأمان إلى أن تستبدلها:

```bash
USB_DEVICE=/dev/disk/by-id/usb-REPLACE_WITH_REVIEWED_DEVICE_ID
ISO_FILE=$(find . -maxdepth 1 -type f \
    -name 'edbp-*-amd64.hybrid.iso' -print -quit)

case "$USB_DEVICE" in
    *-part*) echo 'ERROR: اختر الجهاز الكامل، لا قسمًا.' >&2; exit 1 ;;
esac
test -n "$ISO_FILE" && test -f "$ISO_FILE"
test -b "$USB_DEVICE"
readlink -f "$USB_DEVICE"
lsblk -o NAME,PATH,SIZE,MODEL,SERIAL,TRAN,TYPE,MOUNTPOINTS "$USB_DEVICE"
```

> **توقف وراجع الآن:** الأمر التالي مدمر. لا تنفذه إلا إذا كان `readlink` و`lsblk` يعرضان USB الصحيح وكانت كل أقسامه غير مركبة. اختيار قرص النظام سيمحو بياناته.

```bash
sudo dd if="$ISO_FILE" of="$USB_DEVICE" \
    bs=4M status=progress conv=fsync
sync
```

بعد انتهاء `dd` وعودة موجه الأوامر، أخرج USB بأمان.

## 10. تشغيل الـLive والتثبيت

1. صِل USB بالجهاز الهدف وافتح قائمة الإقلاع الخاصة بالـUEFI.
2. اختر USB في وضع UEFI. Legacy BIOS/CSM غير مدعوم عمدًا.
3. اختر Live لتجربة الشاشة والشبكة والطباعة والماوس ولوحة المفاتيح دون تثبيت، أو اختر واجهة Debian Installer الرسومية للبدء مباشرة.
4. عند التقسيم، راجع اسم القرص وسعته بعناية. المشروع يفرض GPT/UEFI لكنه لا يختار القرص أو طريقة التقسيم ولا يؤكد الكتابة نيابة عنك.
5. يكمل installer من نظام Live الموجود في الـISO. `netcfg` ومرايا APT و`apt-cdrom` غير مستخدمة أثناء التثبيت، لذلك لا يحتاج الجهاز الهدف إلى الإنترنت.
6. ينشأ `localadmin` من hash البناء، وتثبت مفاتيحه العامة، وتولد مفاتيح SSH host فريدة، وتفعل خدمات EDBP المطلوبة.
7. بعد اكتمال target ومرحلة `Finish the installation`، ينهي installer المتداخل مساره بعد فك target ويعود بصورة سليمة إلى بيئة Live بدل تنفيذ reboot من داخلها.
8. أعد تشغيل الجهاز من واجهة Live، وانزع USB حتى يقلع من القرص المثبت.

لا تعالج أي فشل بتجاوز تأكيد التقسيم أو بتشغيل الشبكة أثناء التثبيت. دوّن الرسالة وراجع `build.log` ونتائج بوابات القبول.

## 11. أول تشغيل — OOBE

عند أول إقلاع من النظام المثبت، يمنع EDBP شاشة SDDM مؤقتًا ويعرض إعداد OOBE في الطرفية. يطلب ثلاث قيم:

### اسم الجهاز

الصيغة الدقيقة:

```text
^[A-Z]+(-[A-Z]+)*-[0-9]{2}$
```

القواعد:

- أحرف إنجليزية كبيرة فقط في كل مقطع.
- شرطة واحدة بين المقاطع.
- شرطة ثم رقمان عشريان بالضبط في النهاية.
- الطول الكلي لا يتجاوز 63 محرفًا.

أمثلة صحيحة: `IT-01`، `IT-SUP-01`، `IT-HQ-SUP-01`.

أمثلة مرفوضة: `it-01`، `IT-SUP`، `IT--SUP-01`، `IT-SUP-1`.

### اسم المستخدم اليومي

الصيغة الدقيقة:

```text
^[a-z][a-z0-9]+(\.[a-z][a-z0-9]+)+$
```

القواعد:

- الطول الكلي من 5 إلى 32 محرفًا.
- مقطعان أو أكثر تفصل بينها نقطة واحدة.
- يبدأ كل مقطع بحرف إنجليزي صغير ويحتوي محرفين على الأقل.
- بقية محارف المقطع أحرف صغيرة أو أرقام.
- لا شرطة ولا underscore ولا مسافة ولا نقاط متكررة.
- الاسم `localadmin` محجوز، وأي اسم مستخدم أو مجموعة موجودة مسبقًا مرفوض.

أمثلة صحيحة: `ab.cd`، `os.haddad`، `ali.ahmad.haddad`.

أمثلة مرفوضة: `a.haddad`، `ab.c`، `ab..cd`، `Ab.cd`، `ab-cd`.

### كلمة مرور المستخدم اليومي

- الطول من 12 إلى 128 محرفًا.
- لا تقبل النقطتين الرأسيتين `:`.
- لا يجوز أن تساوي اسم المستخدم.

أنشئ OOBE هذا الحساب كمستخدم عادي بلا `sudo`. المجموعة الإضافية الوحيدة له هي `scanner`. إذا انقطع التيار في أثناء المعاملة، يحاول OOBE التراجع بأمان ثم يعيد الإعداد في الإقلاع التالي. بعد نجاحه يبدأ SDDM ويمكن للمستخدم تسجيل الدخول.

## 12. حساب `localadmin`

`localadmin` حساب الفني أو مسؤول الطوارئ، وليس حساب العمل اليومي. خصائصه:

- يستطيع تشغيل `sudo`، وتبقى كلمة المرور مطلوبة.
- يستطيع تسجيل الدخول محليًا بكلمة المرور التي ولّد المشغل hash لها وقت البناء.
- SSH متاح له بالمفاتيح العامة التي وضعت في `secrets/localadmin_authorized_keys`؛ تسجيل SSH بكلمة مرور معطل.
- هو مخفي من قائمة مستخدمي SDDM لتقليل الاستخدام العرضي، لكن يمكن كتابة اسمه يدويًا عند الحاجة التشغيلية.
- يولد كل تثبيت مفاتيح SSH host جديدة، لذلك لا تشترك الأجهزة في هوية خادم واحدة.

المستخدم الذي ينشئه OOBE منفصل: لا يحصل على `sudo` ولا يسمح له إعداد SSH الحالي بتسجيل الدخول عن بعد. استخدم `localadmin` للصيانة المضبوطة، والمستخدم العادي للأعمال اليومية.

## 13. الشبكة والسياسات الأمنية

### الشبكة و`nftables`

التثبيت نفسه offline. بعد الإقلاع المثبت يدير NetworkManager اتصال Ethernet أو Wi-Fi. يعمل `nftables.service` افتراضيًا بسياسة drop، ويسمح بالـloopback والاتصالات المنشأة وبحركة IPv4 الجديدة ضمن شبكات LAN الخاصة `10.0.0.0/8` و`172.16.0.0/12` و`192.168.0.0/16` وlink-local `169.254.0.0/16`. تمرير الحزم معطل.

إذا اعتمدت الجهة استثناء إنترنت مؤقتًا للصيانة، ينفذه `localadmin` بصورة صريحة:

```bash
sudo systemctl stop nftables.service
sudo nft list ruleset
```

هذا الإجراء يزيل الحماية الافتراضية مؤقتًا، فلا تنفذه دون موافقة إدارية وفي شبكة غير موثوقة. أعد السياسة فور انتهاء العمل وتحقق منها:

```bash
sudo systemctl start nftables.service
sudo nft --check --file /etc/nftables.conf
sudo nft list ruleset
```

لا تستخدم `systemctl disable nftables` ولا تعدل السياسة لتجاوز مشكلة اتصال دون مراجعة.

### USBGuard

يحظر USBGuard أي جهاز يعرض واجهة Mass Storage، بما في ذلك الأجهزة المركبة التي تجمع التخزين مع وظيفة أخرى. يسمح فقط بالمجموعات المعتمدة من HID والطابعة والتصوير، ويحظر الباقي ضمنيًا. يحتاج السماح الاستثنائي بجهاز إلى فني مفوض ومراجعة معرف الجهاز:

```bash
sudo usbguard list-devices
```

لا تنفذ `allow-device` إلا بعد التحقق من الجهاز والحصول على الموافقة التشغيلية.

### Bluetooth وSSH وhistory

- Bluetooth معطل عبر خيارات الإقلاع وسياسة kernel وحظر الحزم ذات الصلة.
- SSH يسمح بالمفتاح العام لحساب `localadmin` فقط؛ root وكلمات مرور SSH وkeyboard-interactive وforwarding معطلة.
- يحتفظ Bash بالأوامر في ذاكرة الجلسة الحالية لتعمل أسهم history و`history`، لكنه يوجه `HISTFILE` إلى `/dev/null` حتى لا تنتقل الأوامر إلى جلسة جديدة.

## 14. المشاكل الشائعة

### `make verify` يفشل بسبب أمر مفقود

**المشكلة:** تظهر رسالة `required build-host command is missing`.

**السبب المحتمل:** إحدى حزم القسم 2 غير مثبتة. `visudo` يوجد في `/usr/sbin/visudo` وتتحقق منه الأداة مباشرة.

**الحل:** ثبّت الحزمة المطابقة، مثل:

```bash
sudo apt install --yes shellcheck sudo debconf openssh-client jq live-build
make verify
```

### شجرة Git غير نظيفة

**المشكلة:** تظهر `source tree is dirty`.

**السبب المحتمل:** يوجد تعديل مقصود أو ملف بناء متبقٍ أو ملف غير متتبع.

**الحل:** اعرض الحالة والفرق أولًا:

```bash
git status --short
git diff --check
git diff
```

راجع كل ملف. استخدم `make clean` لمخرجات البناء المعروفة، والتزم بالتغييرات المصدرية المقصودة وفق سير فريقك. لا تستخدم reset أو clean مدمرًا لإخفاء السبب.

### ملف secrets مفقود أو مرفوض

**المشكلة:** يفشل التحقق من `localadmin_authorized_keys` أو `localadmin_password_hash`.

**السبب المحتمل:** مسار خاطئ، أو symlink، أو صلاحيات/ملكية غير آمنة، أو مفتاح/خوارزمية غير مدعومة.

**الحل:** أعد خطوات القسم 4 ثم افحص metadata دون طباعة الأسرار:

```bash
chmod 700 secrets
chmod 600 \
    secrets/localadmin_authorized_keys \
    secrets/localadmin_password_hash
stat -c 'file=%n owner=%U:%G mode=%a bytes=%s' secrets/*
make verify
```

### لم ينتج ملف ISO

**المشكلة:** انتهى `make all` بخطأ ولا يوجد `edbp-*-amd64.hybrid.iso` صالح.

**السبب المحتمل:** انقطاع شبكة البناء، نقص مساحة، خطأ حزمة، أو فشل تحقق.

**الحل:** اقرأ آخر السجل وافحص المساحة قبل إعادة المحاولة:

```bash
test -f build.log && tail -n 100 build.log
df -h .
git status --short
```

صحح السبب، ثم شغّل `make clean` و`make verify` و`make all`. لا تعتبر ISO جزئيًا ناتجًا صالحًا.

### USB لا يقلع

**المشكلة:** لا يظهر USB أو يعود firmware إلى القرص.

**السبب المحتمل:** الإقلاع مضبوط على Legacy/CSM، أو كتبت الصورة إلى قسم بدل الجهاز الكامل، أو لم يكتمل النسخ، أو الـISO تالف.

**الحل:** تحقق من `SHA256SUMS`، وأعد الكتابة بعد مراجعة الجهاز، واختر مدخل UEFI من قائمة firmware. Secure Boot مضبوط على `auto` مع shim/GRUB الموقّعين؛ لا تتجاوز سياسة firmware لمجرد إخفاء خطأ غير مشخص.

### OOBE يرفض اسم الجهاز أو المستخدم

**المشكلة:** تعود شاشة الإدخال برسالة validation.

**السبب المحتمل:** القيمة لا تطابق القواعد الدقيقة.

**الحل:** استخدم نموذجًا مثل `IT-HQ-01` للجهاز و`os.haddad` للمستخدم، مع الحدود المذكورة في القسم 11.

## 15. تحديث المشروع لاحقًا

قبل جلب تحديثات، ادخل المستودع وتأكد أن عملك محفوظ وأن الشجرة نظيفة:

```bash
cd EDBP
git status --short --branch
```

إذا ظهرت تغييرات، راجعها ولا تتابع حتى تلتزم بها أو تحفظها وفق سير فريقك. بعد ذلك:

```bash
git fetch --prune origin
git pull --ff-only
```

`git fetch` يجلب معلومات التحديث دون تعديل ملفات العمل. `git pull --ff-only` يحدث الفرع الحالي فقط إذا أمكن تحريكه إلى الأمام دون merge ضمني؛ إذا رفض، توقف واطلب مراجعة مسؤول Git بدل استخدام force أو `reset --hard`.

بعد التحديث اقرأ التغييرات وملاحظات الإصدار، ثم أعد الدورة:

```bash
make clean
make verify
make all
```

## 16. ملاحظات أمنية مهمة

> **قائمة أمان مختصرة**
>
> - لا تلتزم `secrets/` في Git ولا تستخدم `git add -f` معه.
> - لا تنسخ مفتاح SSH الخاص إلى المستودع أو الـISO ولا ترسله إلى GitHub.
> - لا تنشر hash كلمة مرور `localadmin` بلا حاجة؛ يمكن استخدامه في تخمين offline.
> - لا تضع كلمة مرور صريحة في script أو command argument أو ticket أو build log.
> - راجع طراز USB وسعته ورقمه التسلسلي قبل أي كتابة؛ `dd` على جهاز خاطئ يمحو البيانات.
> - لا تتجاوز `make verify` ولا تبنِ من شجرة Git متسخة.
> - لا تستخدم `git clean -fdx` أو `git reset --hard` كخطوة تنظيف عادية.
> - احفظ المفتاح الخاص وكلمات المرور في نظام إدارة اعتمادات معتمد ودوّرها عند الاشتباه بالتعرض.

## 17. Quick Start

هذا الملخص لمن قرأ الشرح السابق وفهم مواضع الخطر. لا يحتوي كلمة مرور أو مفتاحًا خاصًا. نفّذه على Debian 13 Trixie:

```bash
sudo apt update
sudo apt install --yes \
    live-build debootstrap squashfs-tools xorriso \
    grub-efi-amd64-bin shim-signed mtools dosfstools \
    make git jq openssh-client sudo shellcheck \
    debconf python3 ca-certificates whois

git clone https://github.com/Q-D-4/EDBP.git
cd EDBP

mkdir -p secrets
chmod 700 secrets

( umask 077; mkpasswd --method=yescrypt > secrets/localadmin_password_hash )
chmod 600 secrets/localadmin_password_hash

install -d -m 700 "$HOME/.ssh"
ssh-keygen -t ed25519 -a 100 \
    -f "$HOME/.ssh/edbp_localadmin_ed25519" \
    -C "edbp-localadmin"
install -m 600 \
    "$HOME/.ssh/edbp_localadmin_ed25519.pub" \
    secrets/localadmin_authorized_keys

stat -c 'file=%n owner=%U:%G mode=%a bytes=%s' \
    secrets/localadmin_password_hash \
    secrets/localadmin_authorized_keys
test -z "$(git ls-files -- \
    secrets/localadmin_password_hash \
    secrets/localadmin_authorized_keys)"
git check-ignore -v \
    secrets/localadmin_password_hash \
    secrets/localadmin_authorized_keys
git status --short

make verify
make clean
make verify
make all

ls -lh edbp-*-amd64.hybrid.iso
sha256sum --check --strict SHA256SUMS
```

بعد نجاح checksums، استخدم القسم 9 لكتابة الـISO على USB بعد التحقق من الجهاز، ثم نفذ اختبار Live وتثبيتًا تجريبيًا كاملًا قبل النشر.
