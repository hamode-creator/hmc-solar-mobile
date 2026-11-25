import 'package:app_attest/app_attest.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'config.dart';
import 'ios_challenge.dart';

/// The iOS Keychain can outlive an app reinstall, while Apple's App Attest
/// Secure Enclave key does not. An invalid cached key must be discarded and
/// attested again; never fall back to an unauthenticated serial lookup.
class IosAttestKeyNeedsRegistration implements Exception {
  const IosAttestKeyNeedsRegistration();
}

/// Only reset when native Apple explicitly identifies an invalid key.
/// Network, rate-limit and server errors must not trigger key rotation.
bool isInvalidAppAttestKeyError(PlatformException exception) {
  final details = '${exception.code} ${exception.message ?? ''}'.toLowerCase();
  return details.contains('invalidkey') ||
      details.contains('invalid_key') ||
      details.contains('invalid key');
}

/// iOS proof generation only. The HMC server is the final authority.
/// This class is deliberately gated off by HmcConfig.iosAttestationEnabled
/// until production Apple certificate-chain and assertion verification exists.
class IosAppAttestClient {
  IosAppAttestClient({required this.post});

  final Future<Map<String, dynamic>> Function(
      String endpoint, Map<String, dynamic> body) post;

  // A key registered with the staging backend is not registered with production.
  // Namespace the keychain value by trusted, compile-time backend hostname.
  static String get _keyField =>
      'hmc_ios_app_attest_key_id_v2_${Uri.parse(HmcConfig.supabaseUrl).host}';
  Future<String>? _registrationInFlight;
  final FlutterSecureStorage _secureStore = const FlutterSecureStorage();

  /// Avoid multiple Secure Enclave registrations if verification is tapped twice.
  Future<String> _getRegisteredKey() {
    if (_registrationInFlight != null) return _registrationInFlight!;
    final registration = _readOrRegister();
    _registrationInFlight = registration;
    return registration.whenComplete(() => _registrationInFlight = null);
  }

  Future<String> _readOrRegister() async {
    final cached = await _secureStore.read(key: _keyField);
    if (cached != null && cached.isNotEmpty) return cached;
    if (!await AppAttest.isSupported()) {
      throw StateError('App Attest not supported on this iPhone.');
    }

    // Server issues registration challenges, but registration stays disabled
    // until the Apple certificate and signature verifier is audited.
    final challenge = await post(
        'verification-challenge', {'purpose': 'ios-register'});
    final (:id, :nonce) = parseIosChallenge(challenge);

    // Generate a non-exportable Secure Enclave key. Never store it until
    // the server validates Apple's certificate chain and records the public key.
    final keyId = await AppAttest.generateKey();
    final material = await AppAttest.attestKey(
      keyId: keyId,
      challenge: nonce,
    );
    final result = await post('register-ios', {
      'challenge_id': id,
      'key_id': keyId,
      'attestation_object': material.attestationObject,
    });
    if (result['registered'] != true) {
      throw StateError('App Attest registration was not accepted by HMC.');
    }
    await _secureStore.write(key: _keyField, value: keyId);
    return keyId;
  }

  Future<String> _assertWithKeyRecovery(String keyId, String clientData) async {
    try {
      final assertion = await AppAttest.generateAssertion(
        keyId: keyId,
        challenge: clientData,
      );
      return assertion.assertionObject;
    } on PlatformException catch (error) {
      if (!isInvalidAppAttestKeyError(error)) rethrow;
      // Re-registration happens only after a new user-initiated attempt,
      // using a NEW one-time server challenge and verified Apple attestation.
      await _secureStore.delete(key: _keyField);
      throw const IosAttestKeyNeedsRegistration();
    }
  }

  Future<Map<String, dynamic>> verify(String serial) async {
    final keyId = await _getRegisteredKey();
    final challenge = await post(
        'verification-challenge', {'purpose': 'verify'});
    final (:id, :nonce) = parseIosChallenge(challenge);
    // The native plugin hashes this UTF-8 client data with SHA-256. Backend
    // must independently derive exactly the same content and verify the
    // App Attest P-256 signature and monotonically increasing sign counter.
    final clientData = 'HMC_VERIFY_V1\n$id\n$nonce\n$serial';
    final assertionObject = await _assertWithKeyRecovery(keyId, clientData);
    return post('check-serial', {
      'platform': 'ios',
      'serial_number': serial,
      'challenge_id': id,
      'key_id': keyId,
      'assertion_object': assertionObject,
    });
  }
}
