import 'package:flutter_test/flutter_test.dart';
import 'package:hmc_solar_verify/ios_app_attest_client.dart';

void main() {
  test('iOS attestation keys are isolated across production and staging', () {
    final production = iosAttestStorageKeyForBackend(
      'https://obloojlkjnagpdokofgw.supabase.co',
    );
    final staging = iosAttestStorageKeyForBackend(
      'https://uyinxppcgcnhfzxwqtzi.supabase.co',
    );
    expect(production, isNot(staging));
    expect(production, contains('obloojlkjnagpdokofgw'));
    expect(staging, contains('uyinxppcgcnhfzxwqtzi'));
  });

  test('iOS attestation storage key rejects insecure backend URLs', () {
    expect(
      () => iosAttestStorageKeyForBackend('http://example.invalid'),
      throwsArgumentError,
    );
  });
}
