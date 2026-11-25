# HMC Solar — App Store listing and review draft
Prepared for the iOS release. Review all text in App Store Connect before submitting. No automatic submission is configured.

## English (en-US)

**App name:** HMC Solar

**Subtitle:** Verify HMC Device Sales

**Promotional text:**
Verify whether an equipment serial number is recorded as sold by HMC Solar. Enter a serial number or scan a supported barcode or QR code.

**Description:**
HMC Solar Serial Verification helps customers check whether an equipment serial number is recorded as sold in HMC Solar's system.

Enter a serial number manually, paste it, or use the camera to scan a supported barcode or QR code. The app securely checks the serial against HMC Solar's sale records and displays whether a confirmed sale was found.

Features:
- Verify equipment serial numbers against HMC Solar's sale records
- Scan supported barcodes and QR codes
- Enter or paste a serial number
- Switch between Arabic and English
- Use the app without creating an account

A result of “No confirmed sale” means that HMC Solar has no confirmed sale record for that serial. It does not mean the equipment is counterfeit. A verified sale does not independently certify manufacturer authenticity, product condition, or warranty coverage.

**Keywords:** HMC Solar,serial,verification,solar,barcode,QR

**Suggested category:** Utilities (confirm in App Store Connect)

## Arabic (ar)

**App name:** HMC Solar

**Subtitle:** التحقق من مبيعات الأجهزة

**Promotional text:**
تحقق مما إذا كان الرقم التسلسلي لجهازك مسجلاً كمباع لدى HMC Solar، من خلال إدخال السيريال أو مسح الرمز بالكاميرا.

**Description:**
يتيح تطبيق HMC Solar للعملاء التحقق مما إذا كان الرقم التسلسلي للجهاز مسجلاً ضمن سجلات البيع لدى شركة HMC Solar.

يمكن إدخال الرقم التسلسلي يدوياً، أو لصقه، أو مسح رمز باركود أو QR مدعوم باستخدام الكاميرا. يتحقق التطبيق من سجل البيع ويعرض ما إذا كان هناك بيع مؤكد لهذا السيريال.

الميزات:
- التحقق من تسجيل السيريال ضمن سجلات مبيعات HMC Solar
- مسح رموز الباركود وQR المدعومة
- إدخال السيريال أو لصقه
- التبديل بين العربية والإنجليزية
- الاستخدام دون إنشاء حساب

عدم العثور على بيع مؤكد يعني عدم وجود سجل بيع مؤكد لدى HMC Solar لهذا الرقم، ولا يعني بالضرورة أن الجهاز مقلد. كما أن تأكيد البيع لا يمثل شهادة مستقلة من الشركة المصنعة بشأن الأصالة أو حالة المنتج أو الضمان.

**Keywords:** طاقة شمسية,سيريال,تحقق,الباركود,الأجهزة,مبيعات

## App Review notes (English)

HMC Solar is a public customer-facing serial-number sales-record lookup application. No account or login is required. The app checks whether a serial number is recorded as SOLD by HMC Solar and does not disclose customer or inventory information. Users can type or paste a serial number, or scan a supported barcode/QR code. Camera access is used only for scanning.

The iOS build uses Apple App Attest and a one-time server challenge for app integrity verification. Internet access and an App Attest-capable physical device are required for a successful verification.

A valid serial format is 6–80 supported characters. The application returns an unconfirmed-sale result for a well-formed serial that has no sale record. For a positive test, HMC Solar must provide App Review with a dedicated, non-customer test serial that is safely recorded as sold in production; do not put real customer serials in public GitHub repositories.

A verified HMC sale record is not a manufacturer authenticity or warranty certificate.

## Required before submission
- Publish an accurate privacy policy at a publicly accessible company-controlled URL. Include the same link within the app. Review server logs, App Attest, challenge data, identifiers, and data retention before selecting App Privacy answers.
- Verify the official support URL has functioning contact details. Do not fabricate addresses, phone numbers, or support email.
- Capture authentic iPhone screenshots from the signed release application (and iPad screenshots if iPadOS is supported).
- Supply a safe positive-sale test serial privately in App Review notes, and one unrelated well-formed serial as a negative test. Do not insert dummy sales into production without explicit approval.
- Complete age rating, rights, pricing, availability, compliance, and App Review contact information.
- Select the already-tested production-backend build if App Store Connect permits it.
- Use manual release after approval; do not enable automatic App Store submission.
