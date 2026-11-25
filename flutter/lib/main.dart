import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import 'verify_service.dart';

void main() => runApp(const HmcSolarApp());

const _navy = Color(0xFF0A2857);
const _blue = Color(0xFF1456AD);
const _softBlue = Color(0xFFEAF2FC);
const _subtle = Color(0xFF657893);
const _border = Color(0xFFDCE6F2);

class HmcSolarApp extends StatelessWidget {
  const HmcSolarApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'HMC Solar',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: _blue,
            primary: _blue,
            surface: Colors.white,
          ),
          scaffoldBackgroundColor: const Color(0xFFF5F8FC),
          textTheme: Theme.of(context).textTheme.apply(
                bodyColor: _navy,
                displayColor: _navy,
              ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFF9FBFF),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: _border),
                borderRadius: BorderRadius.circular(15)),
            focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: _blue, width: 1.6),
                borderRadius: BorderRadius.circular(15)),
          ),
        ),
        home: const VerifyPage(),
      );
}

class VerifyPage extends StatefulWidget {
  const VerifyPage({super.key});

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  final TextEditingController _serial = TextEditingController();
  final VerificationService _service = VerificationService();
  final ScrollController _pageScroll = ScrollController();
  bool _arabic = true;
  bool _loading = false;
  bool? _confirmed;
  String? _error;
  String _checkedSerial = '';

  String tr(String ar, String en) => _arabic ? ar : en;

  @override
  void initState() {
    super.initState();
    // Android Play Integrity warm-up. An unavailable provider never grants
    // permission to bypass server verification.
    _service.prepareAndroid().catchError((Object _) {});
  }

  void _clearResult() {
    setState(() {
      _confirmed = null;
      _error = null;
      _checkedSerial = '';
    });
  }

  // Build all form/result children and scroll them into view after a result.
  // A lazily-built ListView could leave the error outside the widget tree.
  void _revealFeedback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageScroll.hasClients) return;
      _pageScroll.animateTo(
        _pageScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _verify() async {
    if (_loading) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final serial = normalizeSerial(_serial.text);
    if (!isValidSerial(serial)) {
      setState(() {
        _error = tr('السيريال غير صحيح. أدخل من 6 إلى 80 رمزاً.',
            'Invalid serial. Enter 6–80 supported characters.');
        _confirmed = null;
      });
      _revealFeedback();
      return;
    }
    setState(() {
      _loading = true;
      _confirmed = null;
      _error = null;
    });
    try {
      final result = await _service.verify(serial);
      if (!mounted) return;
      setState(() {
        _checkedSerial = serial;
        _confirmed = result.confirmed;
      });
      _revealFeedback();
    } on VerificationException catch (e) {
      if (mounted) {
        setState(() => _error = _arabic ? e.message
            : 'Verification could not be completed. Check that the official app is configured and try again.');
        _revealFeedback();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = tr('حدث خطأ غير متوقع. حاول مرة ثانية.',
            'Something went wrong. Please try again.'));
        _revealFeedback();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pasteSerial() async {
    if (_loading) return;
    ClipboardData? data;
    try {
      data = await Clipboard.getData(Clipboard.kTextPlain);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = tr('تعذّر قراءة الحافظة. أدخل السيريال يدوياً.',
          'Could not read clipboard. Enter the serial manually.'));
      return;
    }
    if (!mounted || data?.text == null) return;
    final candidate = normalizeScannedSerial(data!.text!);
    if (candidate == null) {
      setState(() {
        _confirmed = null;
        _error = tr('النص المنسوخ لا يحتوي على سيريال صحيح.',
            'Clipboard does not contain a valid serial number.');
      });
      return;
    }
    _serial.text = candidate;
    _clearResult();
  }

  static final Uri _privacyPolicyUrl =
      Uri.parse('https://hamode-creator.github.io/hmc-solar-mobile/privacy/');

  Future<void> _openPrivacyPolicy() async {
    bool opened = false;
    try {
      opened = await launchUrl(_privacyPolicyUrl,
          mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(
          'تعذر فتح سياسة الخصوصية. حاول مرة أخرى.',
          'Could not open the privacy policy. Please try again.',
        ))),
      );
    }
  }

  Future<void> _scan() async {
    if (_loading) return;
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => SerialScanner(arabic: _arabic),
      ),
    );
    if (!mounted || scanned == null) return;
    _serial.text = scanned;
    _clearResult();
  }

  @override
  void dispose() {
    _serial.dispose();
    _pageScroll.dispose();
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final direction = _arabic ? TextDirection.rtl : TextDirection.ltr;
    return Directionality(
      textDirection: direction,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 18,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.asset('assets/hmc_logo.png', fit: BoxFit.contain),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('HMC Solar',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: _navy)),
                    Text('SERIAL VERIFICATION',
                        style: TextStyle(
                            letterSpacing: 1.1,
                            fontSize: 9,
                            color: _subtle,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 14),
              child: TextButton(
                onPressed: () {
                  if (_loading) return;
                  setState(() => _arabic = !_arabic);
                },
                child: Text(_arabic ? 'EN' : 'عربي',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: SingleChildScrollView(
                controller: _pageScroll,
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  _hero(),
                  const SizedBox(height: 22),
                  _verificationForm(),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _resultCard(
                      positive: false,
                      icon: Icons.error_outline,
                      title: tr('لم يكتمل الفحص', 'Verification unavailable'),
                      message: _error!,
                      isError: true,
                    ),
                  ],
                  if (_confirmed != null) ...[
                    const SizedBox(height: 16),
                    _resultCard(
                      positive: _confirmed!,
                      icon: _confirmed!
                          ? Icons.verified_rounded
                          : Icons.info_outline_rounded,
                      title: _confirmed!
                          ? tr('تم تأكيد البيع من HMC',
                              'Sale verified by HMC')
                          : tr('لا يوجد بيع مؤكّد لهذا الرقم',
                              'No confirmed sale for this serial'),
                      message: _confirmed!
                          ? tr('هذا السيريال مسجل كجهاز مباع في نظام HMC Solar.',
                              'This serial is recorded as sold in the HMC Solar system.')
                          : tr(
                              'لم نجد سجل بيع مؤكداً لهذا الرقم لدى HMC. هذا لا يعني أن الجهاز غير أصلي.',
                              'No confirmed HMC sale was found. This does not mean the device is counterfeit.'),
                      serial: _checkedSerial,
                    ),
                  ],
                  const SizedBox(height: 22),
                  _privacyNote(),
                  const SizedBox(height: 30),
                  Center(
                    child: Text('HMC SOLAR  ·  IRAQ',
                        style: TextStyle(
                          color: _subtle.withValues(alpha: 0.8),
                          fontSize: 10,
                          letterSpacing: 1.7,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
       ),
    );
  }

  Widget _hero() => Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [_navy, _blue],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.verified_user_outlined,
                  color: Colors.white, size: 29),
            ),
            const SizedBox(height: 17),
            Text(tr('تحقق من جهازك', 'Verify your device'),
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                  color: Colors.white,
                )),
            const SizedBox(height: 10),
            Text(
              tr('تأكد أن السيريال مسجل ومباع من شركة HMC Solar مباشرة.',
                  'Check whether your serial number is registered as sold by HMC Solar.'),
              style: TextStyle(
                  fontSize: 13.5,
                  height: 1.65,
                  color: Colors.white.withValues(alpha: 0.86)),
            ),
          ],
        ),
      );

  Widget _verificationForm() => Container(
        padding: const EdgeInsets.all(21),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: _navy.withValues(alpha: 0.045),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Icon(Icons.numbers_rounded, color: _blue, size: 20),
              const SizedBox(width: 8),
              Text(tr('الرقم التسلسلي (Serial Number)', 'Serial number'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: _navy)),
            ]),
            const SizedBox(height: 13),
            Directionality(
              textDirection: TextDirection.ltr,
              child: TextField(
                controller: _serial,
                enabled: !_loading,
                onChanged: (_) => _clearResult(),
                textInputAction: TextInputAction.search,
                keyboardType: TextInputType.text,
                onSubmitted: (_) => _verify(),
                maxLength: 80,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: _navy),
                decoration: InputDecoration(
                  hintText: 'e.g. HMC123456789',
                  counterText: '',
                  suffixIcon: IconButton(
                    tooltip: tr('مسح', 'Clear'),
                    onPressed: _loading
                        ? null
                        : () {
                            _serial.clear();
                            _clearResult();
                          },
                    icon: const Icon(Icons.close_rounded,
                        size: 19, color: _subtle),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: _loading ? null : _pasteSerial,
                icon: const Icon(Icons.content_paste_outlined, size: 18),
                label: Text(tr('لصق السيريال', 'Paste serial')),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _loading ? null : _verify,
              style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  disabledBackgroundColor: _blue.withValues(alpha: 0.55),
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Colors.white))
                  : const Icon(Icons.fact_check_outlined),
              label: Text(
                _loading
                    ? tr('جارٍ التحقق...', 'Verifying...')
                    : tr('تحقق من السيريال', 'Verify serial number'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _loading ? null : _scan,
              style: OutlinedButton.styleFrom(
                foregroundColor: _blue,
                minimumSize: const Size.fromHeight(52),
                side: const BorderSide(color: _border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: Text(tr('امسح الباركود بالكاميرا', 'Scan a barcode'),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 13),
            Text(
              tr('لا تحتاج إلى تسجيل دخول. يتم الفحص عند الضغط على زر التحقق فقط.',
                  'No sign-in required. Verification runs only when you submit.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11.5, height: 1.6, color: _subtle),
            ),
          ],
        ),
      );

  Widget _resultCard({
    required bool positive,
    required IconData icon,
    required String title,
    required String message,
    String? serial,
    bool isError = false,
  }) {
    final accent = positive
        ? const Color(0xFF16814D)
        : (isError ? const Color(0xFF9C4E22) : _blue);
    final background = positive
        ? const Color(0xFFEFFAF3)
        : (isError ? const Color(0xFFFFF7EE) : _softBlue);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: accent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      color: accent,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(height: 7),
                Text(message,
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 12.5,
                      height: 1.65,
                    )),
                if (serial != null) ...[
                  const SizedBox(height: 10),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: SelectableText(serial,
                        style: TextStyle(
                            color: accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6)),
                  ),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _privacyNote() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          children: [
            const Icon(Icons.lock_outline, color: _subtle, size: 20),
            const SizedBox(height: 7),
            Text(tr('خصوصية وأمان', 'Privacy & security'),
                style: const TextStyle(
                    color: _navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text(
              tr('نستخدم الرقم التسلسلي للتحقق من سجل البيع. لا نعرض بيانات الزبائن أو المخزون. نتيجة الفحص لا تُثبت الأصالة الفنية أو الضمان.',
                  'We check the serial against HMC sale records. Customer and inventory details are not shown. This result does not certify technical authenticity or warranty.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _subtle, fontSize: 11.5, height: 1.7),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _openPrivacyPolicy,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(tr('قراءة سياسة الخصوصية', 'Read privacy policy')),
            ),
          ],
        ),
      );
}

class SerialScanner extends StatefulWidget {
  const SerialScanner({super.key, required this.arabic});
  final bool arabic;

  @override
  State<SerialScanner> createState() => _SerialScannerState();
}

class _SerialScannerState extends State<SerialScanner> {
  late final MobileScannerController _camera = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: [
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.code93,
        BarcodeFormat.qrCode,
        BarcodeFormat.dataMatrix,
        BarcodeFormat.ean13,
      ]);
  bool _complete = false;
  bool _torch = false;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection:
            widget.arabic ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: _navy,
            foregroundColor: Colors.white,
            title: Text(widget.arabic ? 'مسح سيريال الجهاز' : 'Scan device serial'),
            actions: [
              IconButton(
                onPressed: () async {
                  try {
                    await _camera.toggleTorch();
                    if (mounted) setState(() => _torch = !_torch);
                  } catch (_) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(widget.arabic
                          ? 'المصباح غير متاح على هذا الجهاز.'
                          : 'The flashlight is unavailable on this device.')),
                    );
                  }
                },
                tooltip: widget.arabic ? 'المصباح' : 'Flashlight',
                icon: Icon(_torch ? Icons.flash_on : Icons.flash_off),
              ),
            ],
          ),
          body: Stack(
            children: [
              MobileScanner(
                controller: _camera,
                errorBuilder: (context, error) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.no_photography_outlined,
                            color: Colors.white, size: 52),
                        const SizedBox(height: 16),
                        Text(widget.arabic
                            ? 'تعذّر فتح الكاميرا. تأكد من صلاحية الكاميرا في إعدادات الآيفون، أو أدخل السيريال يدوياً.'
                            : 'Camera unavailable. Check camera permissions in iPhone Settings or enter the serial manually.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white,
                              fontSize: 15, height: 1.6)),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(widget.arabic ? 'رجوع' : 'Go back'),
                        ),
                      ],
                    ),
                  ),
                ),
                onDetect: (capture) {
                  if (_complete) return;
                  for (final code in capture.barcodes) {
                    final raw = code.rawValue;
                    if (raw == null) continue;
                    final serial = normalizeScannedSerial(raw);
                    if (serial == null) continue;
                    _complete = true;
                    Navigator.of(context).pop(serial);
                    break;
                  }
                },
              ),
              Center(
                child: IgnorePointer(
                  child: Container(
                    width: 290,
                    height: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  color: _navy.withValues(alpha: 0.93),
                  child: SafeArea(
                    top: false,
                    child: Text(
                      widget.arabic
                          ? 'وجّه الكاميرا نحو الباركود أو QR الذي يحتوي على السيريال.'
                          : 'Point the camera at the serial barcode or QR code.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.5,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
