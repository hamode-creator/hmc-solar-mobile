import 'dart:convert';
import 'dart:io';

import 'package:app_attest/app_attest.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
import 'ios_app_attest_client.dart';

class VerificationResult {
  const VerificationResult(this.confirmed);
  /// True only when the trusted server confirms the serial is SOLD by HMC.
  final bool confirmed;
}

class VerificationException implements Exception {
  const VerificationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The same canonicalization applied by the HMC Supabase Edge Function.
String normalizeSerial(String input) =>
    input.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

bool isValidSerial(String value) =>
    RegExp(r'^[A-Z0-9_./:]{6,80}$').hasMatch(value);

/// Scan a serial, rather than silently treating arbitrary QR URLs as serials.
/// Example supported formats: ABC123456, S/N: ABC123456, SN=ABC123456.
String? normalizeScannedSerial(String raw) {
  var candidate = raw.trim();
  // QR codes may contain web links. We never infer a serial from a URL.
  if (RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false)
      .hasMatch(candidate)) return null;
  final labelled = RegExp(r'^\s*(?:S\s*[/.-]?\s*N|SERIAL(?:\s+NUMBER)?)\s*[:=#]\s*(.+?)\s*$',
      caseSensitive: false).firstMatch(candidate);
  if (labelled != null) candidate = labelled.group(1)!;
  final serial = normalizeSerial(candidate);
  return isValidSerial(serial) ? serial : null;
}

/// Must match HMC check-serial Edge Function: HMC_VERIFY_V1\nID\nNONCE\nSERIAL.
String boundRequestHash(String id, String nonce, String serial) {
  final canonical = 'HMC_VERIFY_V1\n$id\n$nonce\n$serial';
  final bytes = sha256.convert(utf8.encode(canonical)).bytes;
  return base64Url.encode(bytes).replaceAll('=', '');
}

class VerificationService {
  VerificationService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  bool _androidPrepared = false;

  Future<void> prepareAndroid() async {
    if (!Platform.isAndroid || _androidPrepared) return;
    final number = int.tryParse(HmcConfig.googleCloudProjectNumber);
    if (number == null || number <= 0) {
      throw const VerificationException(
          'Google Play Integrity غير مفعّل للتطبيق بعد.');
    }
    try {
      await AppAttest.preparePlayIntegrityTokenProvider(
        cloudProjectNumber: number,
      );
      _androidPrepared = true;
    } catch (_) {
      throw const VerificationException(
          'تعذّر تهيئة التحقق من تطبيق Google Play. حاول لاحقاً.');
    }
  }

  Future<Map<String, dynamic>> _post(
      String functionName, Map<String, dynamic> input) async {
    final base = Uri.tryParse(HmcConfig.supabaseUrl);
    if (base == null || base.scheme != 'https' || base.host.isEmpty) {
      throw const VerificationException('عنوان خادم HMC غير صالح.');
    }
    final endpoint = base.replace(path: '/functions/v1/$functionName');
    late final http.Response response;
    try {
      response = await _client
          .post(endpoint,
              headers: const {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode(input))
          .timeout(const Duration(seconds: 22));
    } catch (_) {
      throw const VerificationException(
          'تعذّر الاتصال بالخادم. تحقق من الإنترنت وحاول مرة ثانية.');
    }
    if (response.statusCode == 429) {
      throw const VerificationException(
          'وصلت إلى الحد المسموح للفحص. حاول بعد قليل.');
    }
    if (response.statusCode >= 500) {
      throw const VerificationException(
          'خدمة التحقق غير متاحة مؤقتاً. حاول لاحقاً.');
    }
    if (response.statusCode == 403 || response.statusCode == 401) {
      throw const VerificationException(
          'تعذّر إثبات هوية التطبيق. استخدم النسخة الرسمية المعتمدة.');
    }
    if (response.statusCode != 200) {
      throw const VerificationException('لم تكتمل عملية التحقق من السيريال.');
    }
    try {
      final parsed = jsonDecode(response.body);
      if (parsed is Map<String, dynamic>) return parsed;
    } catch (_) {
      // Never treat a broken/missing response as a negative verification.
    }
    throw const VerificationException('استجابة غير صحيحة من الخادم.');
  }

  Future<VerificationResult> verify(String input) async {
    final serial = normalizeSerial(input);
    if (!isValidSerial(serial)) {
      throw const VerificationException('أدخل سيريال صحيحاً من 6 إلى 80 رمزاً.');
    }
    if (Platform.isIOS) {
      // Server still rejects unverified iPhone requests. The release flag
      // MUST stay false until real App Attest verification has been deployed.
      if (!HmcConfig.iosAttestationEnabled) {
        throw const VerificationException(
          'فحص iPhone قيد التجهيز حتى تفعيل Apple App Attest الآمن.',
        );
      }
      try {
        final result = await IosAppAttestClient(post: _post).verify(serial);
        if (result['confirmed'] is! bool) {
          throw const VerificationException('نتيجة فحص غير صالحة.');
        }
        return VerificationResult(result['confirmed'] as bool);
      } on VerificationException {
        rethrow;
      } on IosAttestKeyNeedsRegistration {
        throw const VerificationException(
            'يحتاج الآيفون إلى إعادة تسجيل مفتاح التحقق. حاول الفحص مرة ثانية.');
      } catch (_) {
        throw const VerificationException(
            'لم يكتمل التحقق الآمن من هوية تطبيق iPhone.');
      }
    }
    if (!Platform.isAndroid) {
      throw const VerificationException('الفحص مخصص لتطبيق iPhone وAndroid.');
    }
    await prepareAndroid();
    final challenge = await _post(
        'verification-challenge', {'purpose': 'verify'});
    final id = challenge['id'];
    final nonce = challenge['challenge'];
    if (id is! String || nonce is! String || nonce.length < 16) {
      throw const VerificationException('تعذّر تجهيز تحدي التحقق الآمن.');
    }
    final hash = boundRequestHash(id, nonce, serial);
    late String token;
    try {
      token = await AppAttest.requestStandardPlayIntegrityToken(
          requestHash: hash);
    } catch (_) {
      // No API fallback without Google's attested verdict.
      _androidPrepared = false;
      throw const VerificationException(
          'فشل التحقق من نسخة Google Play. حاول مجدداً بعد التحديث.');
    }
    final response = await _post('check-serial', {
      'platform': 'android',
      'serial_number': serial,
      'challenge_id': id,
      'integrity_token': token,
    });
    final confirmed = response['confirmed'];
    if (confirmed is! bool) {
      throw const VerificationException('الخادم لم يرجع نتيجة تحقق صحيحة.');
    }
    return VerificationResult(confirmed);
  }

  void dispose() => _client.close();
}
