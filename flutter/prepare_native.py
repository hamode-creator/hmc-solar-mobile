#!/usr/bin/env python3
"""Create Android + iOS Flutter platform projects with HMC identifiers.

Only run on a development machine with Flutter >=3.44 and Python >=3.10.
Does not install dependencies, set secrets, sign builds, or publish anything.
"""
from __future__ import annotations

import pathlib
import plistlib
import re
import shutil
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent
BUNDLE = "com.hmcsolar.verify"


def apply_ios_native_setup() -> None:
    """Configure Xcode files without requiring an activated Team ID.

    Apple credentials remain outside this repository. App Attest is still gated
    by IOS_ATTEST_ENABLED=false until server verification is implemented.
    """
    runner = ROOT / 'ios' / 'Runner'
    plist_file = runner / 'Info.plist'
    if not plist_file.exists():
        raise RuntimeError(f'Missing iOS Info.plist: {plist_file}')
    with plist_file.open('rb') as source:
        plist = plistlib.load(source)
    plist['CFBundleDisplayName'] = 'HMC Solar'
    plist['NSCameraUsageDescription'] = (
        'Use the camera to scan the serial number on HMC Solar equipment. '
        'Camera images are processed on your device.'
    )
    with plist_file.open('wb') as dest:
        plistlib.dump(plist, dest, sort_keys=False)

    entitlements = {
        'Runner-Debug.entitlements': 'development',
        'Runner-Release.entitlements': 'production',
    }
    for filename, environment in entitlements.items():
        with (runner / filename).open('wb') as dest:
            plistlib.dump({
                'com.apple.developer.devicecheck.appattest-environment':
                environment,
                # flutter_secure_storage 11.x uses the iOS Keychain. Without
                # this entitlement, writes may appear successful but fail to
                # persist on physical devices.
                'keychain-access-groups': [],
            }, dest)

    xcodeproj = ROOT / 'ios/Runner.xcodeproj/project.pbxproj'
    source = xcodeproj.read_text()
    def replace_bundle(match: re.Match[str]) -> str:
        old = match.group(2)
        if 'RunnerTests' in old or 'RunnerUITests' in old:
            return match.group(0)
        return match.group(1) + BUNDLE + ';'
    source, count = re.subn(r'(PRODUCT_BUNDLE_IDENTIFIER\s*=\s*)([^;]+);',
                            replace_bundle, source)
    if count < 1:
        raise RuntimeError('iOS bundle identifier missing in Xcode project')
    # All settings blocks are parsed as text, but only the Runner application
    # target includes the exact bundle identifier we set above.
    def patch_config(match: re.Match[str]) -> str:
        body, config_name = match.group('body'), match.group('name')
        if ('PRODUCT_BUNDLE_IDENTIFIER = ' + BUNDLE + ';') not in body:
            return match.group(0)
        ent = ('Runner-Debug.entitlements' if config_name == 'Debug'
               else 'Runner-Release.entitlements')
        if 'CODE_SIGN_ENTITLEMENTS' not in body:
            body += '\n\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/' + ent + ';'
        return match.group('head') + body + match.group('tail')
    block = re.compile(
        r'(?P<head>\t\t[A-F0-9]{24} /\* (?:Debug|Release|Profile) \*/ = \{' 
        r'\s*isa = XCBuildConfiguration;\s*buildSettings = \{)'
        r'(?P<body>.*?)'
        r'(?P<tail>\n\s*\};\s*name = (?P<name>Debug|Release|Profile);\s*\};)',
        re.DOTALL,
    )
    source = block.sub(patch_config, source)
    if 'CODE_SIGN_ENTITLEMENTS = Runner/Runner-' not in source:
        raise RuntimeError('Xcode App Attest entitlements were not attached')
    source = re.sub(r'(IPHONEOS_DEPLOYMENT_TARGET\s*=\s*)[0-9.]+;',
                    r'\g<1>14.0;', source)
    xcodeproj.write_text(source)

    podfile = ROOT / 'ios/Podfile'
    if podfile.exists():
        content = podfile.read_text()
        content = re.sub(r"^\s*#?\s*platform\s*:ios,\s*['\"]\d+(?:\.\d+)?['\"]",
                         "platform :ios, '14.0'", content, count=1, flags=re.MULTILINE)
        podfile.write_text(content)
    print('iOS: HMC bundle ID, camera permission, minimum 14.0, and App Attest entitlements prepared.')


def main() -> None:
    flutter = shutil.which("flutter")
    if not flutter:
        raise SystemExit("Flutter was not found in PATH. Install Flutter 3.44+ first.")
    original_dart = {p: p.read_bytes() for p in (ROOT / "lib").glob("*.dart")}
    subprocess.run(
        [flutter, "create", "--platforms=android,ios", "--org", "com.hmcsolar",
         "--project-name", "hmc_solar_verify", "."],
        cwd=ROOT, check=True,
    )
    # flutter create adds platform templates. Restore our existing custom app
    # source if the generator supplied a starter main.dart.
    for path, original in original_dart.items():
        if path.read_bytes() != original:
            path.write_bytes(original)
    default_test = ROOT / "test/widget_test.dart"
    if default_test.exists():
        sample = default_test.read_text()
        if "const MyApp()" in sample and "flutter_test" in sample:
            default_test.unlink()
    android = ROOT / "android/app/build.gradle.kts"
    if not android.exists():
        raise SystemExit(f"Missing Android Gradle file: {android}")
    raw = android.read_text()
    raw, count = re.subn(r'(applicationId\s*=\s*")[^"]+("\s*)',
                         lambda match: match.group(1) + BUNDLE + match.group(2),
                         raw, count=1)
    if count != 1:
        raise SystemExit("Android applicationId was not found: update it manually.")
    android.write_text(raw)

    apply_ios_native_setup()
    print(f"Native folders prepared. Android applicationId and iOS bundleID: {BUNDLE}")
    print("Next: flutter pub get && flutter analyze && flutter test")
    print("IMPORTANT: Set Apple signing Team & App Attest entitlement in Xcode.")
    print("IMPORTANT: Google Play Integrity requires Play Console setup.")


if __name__ == "__main__":
    main()
