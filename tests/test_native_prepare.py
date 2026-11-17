import importlib.util
import pathlib
import plistlib
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / 'flutter' / 'prepare_native.py'
spec = importlib.util.spec_from_file_location('hmc_native', SCRIPT)
native = importlib.util.module_from_spec(spec)
spec.loader.exec_module(native)


def config(name, appid, code=''):
    return (f'\t\t1234567890ABCDEF1234{hash(name) & 65535:04X} /* {name} */ = {{\n'
            f'\t\t\tisa = XCBuildConfiguration;\n'
            f'\t\t\tbuildSettings = {{\n'
            f'\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = {appid};\n'
            f'\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 13.0;\n'
            f'\t\t\t\t{code}\n'
            f'\t\t\t}};\n'
            f'\t\t\tname = {name};\n'
            f'\t\t}};\n')

class NativeSetupTests(unittest.TestCase):
    def test_app_attest_config_and_runner_tests_isolation(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            runner = root / 'ios' / 'Runner'
            runner.mkdir(parents=True)
            with (runner / 'Info.plist').open('wb') as f:
                plistlib.dump({'CFBundleName': 'Runner'}, f)
            project = root / 'ios' / 'Runner.xcodeproj'
            project.mkdir()
            xcode = project / 'project.pbxproj'
            xcode.write_text(config('Debug', 'com.example.app') +
                             config('Release', 'com.example.app') +
                             config('Profile', 'com.example.app') +
                             config('Debug', 'com.example.app.RunnerTests'))
            (root / 'ios' / 'Podfile').write_text("# platform :ios, '13.0'\n")
            oldroot = native.ROOT
            try:
                native.ROOT = root
                native.apply_ios_native_setup()
                first = xcode.read_text()
                native.apply_ios_native_setup()
                second = xcode.read_text()
            finally:
                native.ROOT = oldroot
            self.assertEqual(first, second, 'must be idempotent')
            self.assertEqual(first.count('CODE_SIGN_ENTITLEMENTS'), 3)
            self.assertIn('CODE_SIGN_ENTITLEMENTS = Runner/Runner-Debug.entitlements;', first)
            self.assertIn('CODE_SIGN_ENTITLEMENTS = Runner/Runner-Release.entitlements;', first)
            self.assertIn('com.example.app.RunnerTests;', first)
            self.assertEqual(first.count('PRODUCT_BUNDLE_IDENTIFIER = com.hmcsolar.verify;'), 3)
            with (runner / 'Info.plist').open('rb') as f:
                plist = plistlib.load(f)
            self.assertEqual(plist['CFBundleDisplayName'], 'HMC Solar')
            self.assertIn('camera', plist['NSCameraUsageDescription'].lower())
            for filename, expected in [('Runner-Debug.entitlements','development'),('Runner-Release.entitlements','production')]:
                with (runner / filename).open('rb') as f:
                    data = plistlib.load(f)
                self.assertEqual(data['com.apple.developer.devicecheck.appattest-environment'],expected)
                self.assertEqual(data['keychain-access-groups'], [],
                                 'secure storage needs Keychain entitlement')
            self.assertIn("platform :ios, '14.0'", (root/'ios/Podfile').read_text())

if __name__ == '__main__': unittest.main()
