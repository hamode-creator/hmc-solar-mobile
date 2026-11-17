"""Offline invariants that should stay true before any TestFlight build."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / 'flutter' / 'lib'

class IosSourceContractTests(unittest.TestCase):
    def test_customer_app_never_embeds_database_secret(self):
        source = '\n'.join(p.read_text() for p in LIB.glob('*.dart'))
        for marker in ['SUPABASE_SERVICE_ROLE_KEY', 'sb_secret_', 'GOOGLE_SERVICE_ACCOUNT_JSON',
                       'APPLE_PRIVATE_KEY', '/rest/v1/hmc_devices']:
            self.assertNotIn(marker, source, marker)

    def test_ios_attestation_defaults_off(self):
        config = (LIB / 'config.dart').read_text()
        self.assertRegex(config, r"bool\.fromEnvironment\('IOS_ATTEST_ENABLED',\s*defaultValue:\s*false\)")
        service = (LIB / 'verify_service.dart').read_text()
        self.assertIn('if (!HmcConfig.iosAttestationEnabled)', service)

    def test_verification_uses_edge_functions_not_direct_inventory(self):
        service = (LIB / 'verify_service.dart').read_text()
        self.assertIn("'/functions/v1/$functionName'", service)
        self.assertIn("'check-serial'", service)
        self.assertNotIn('from(\'hmc_devices\')', service)

    def test_key_recovery_is_limited_to_invalid_key(self):
        client = (LIB / 'ios_app_attest_client.dart').read_text()
        self.assertIn('if (!isInvalidAppAttestKeyError(error)) rethrow;', client)
        self.assertIn('await _secureStore.delete(key: _keyField);', client)
        self.assertIn('IosAttestKeyNeedsRegistration', client)

    def test_scan_error_and_feedback_have_safe_ui(self):
        ui = (LIB / 'main.dart').read_text()
        self.assertIn('child: SingleChildScrollView(', ui)
        self.assertIn('_revealFeedback();', ui)
        self.assertIn('await _camera.toggleTorch();', ui)
        self.assertIn('catch (_)', ui)
        self.assertNotIn('اختبار اتصال Supabase', ui)

    def test_customer_app_has_no_account_or_admin_controls(self):
        ui = (LIB / 'main.dart').read_text()
        self.assertNotIn('AdminDashboard', ui)
        self.assertNotIn('signInWithPassword', ui)
        self.assertNotIn('createDevice(', ui)
        self.assertNotIn('bulkDelete(', ui)

if __name__ == '__main__':
    unittest.main()
