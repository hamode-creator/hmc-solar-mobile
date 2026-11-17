import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmc_solar_verify/ios_app_attest_client.dart';

void main() {
  test('only Apple invalid-key errors are eligible for safe re-registration', () {
    expect(isInvalidAppAttestKeyError(
      PlatformException(code: 'DCError.invalidKey')), isTrue);
    expect(isInvalidAppAttestKeyError(
      PlatformException(code: 'IOS_ERROR', message: 'Invalid key identifier')), isTrue);
    expect(isInvalidAppAttestKeyError(
      PlatformException(code: 'NETWORK_ERROR')), isFalse);
    expect(isInvalidAppAttestKeyError(
      PlatformException(code: 'SERVER_UNAVAILABLE')), isFalse);
    expect(isInvalidAppAttestKeyError(
      PlatformException(code: 'INVALID_INPUT')), isFalse);
  });
}
