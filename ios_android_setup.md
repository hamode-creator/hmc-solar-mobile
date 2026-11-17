# Native setup — HMC Solar customer app

The checked-in project deliberately contains the custom Flutter source, not a pre-built APK/AAB/IPA or a Flutter SDK. Signing and release credentials cannot be embedded in a project archive.

## Required tooling

- Flutter 3.44+ (Dart 3.12+), Python 3 and Android Studio for Android builds
- For iOS: macOS, recent Xcode and membership in the Apple Developer Program (or an appropriate hosted build provider)
- Physical Android phone with Google Play Store for Play Integrity tests
- Physical iPhone for Apple App Attest tests; simulators cannot validate production attestation

## Initialize

In `flutter/`:

```bash
python prepare_native.py
flutter pub get
dart run flutter_launcher_icons
flutter analyze
flutter test
```

`prepare_native.py` calls `flutter create --platforms=android,ios --org com.hmcsolar --project-name hmc_solar_verify .`, preserves the custom Dart files, sets Android applicationId and iOS bundle identifier to `com.hmcsolar.verify`, and adds the native camera permission text to iOS Info.plist. Review generated project settings before signing.

## Android

1. Register `com.hmcsolar.verify` in Google Play Console and enable Play Integrity API in its Google Cloud project.
2. Configure Supabase server-only secrets described in `../RELEASE_CHECKLIST.md`. Never embed a service account key or server secret in the APK.
3. Create the Android signing key or use secure managed Play signing. Build with the **numeric** Google Cloud project number:

```bash
flutter build appbundle --release --dart-define=GOOGLE_CLOUD_PROJECT_NUMBER=123456789012
```

Replace this example number with the actual number from the linked Google Cloud project. The app already knows the non-secret HMC Supabase project URL by default. A debug APK can launch the interface but usually cannot pass the server's `PLAY_RECOGNIZED` requirement.

## iOS

1. Run `python3 prepare_native.py`; it sets the HMC bundle ID, iPhone camera privacy description, iOS 14 minimum and development/production App Attest entitlement files.
2. Select the correct Apple Team in Xcode, register `com.hmcsolar.verify` as the App ID, enable App Attest **and Keychain Sharing** capabilities and configure signing. `prepare_native.py` writes both App Attest and `keychain-access-groups` entitlements; verify that Xcode signing/provisioning retains them.
3. The secure iOS backend is **not active yet**. Keep `IOS_ATTEST_ENABLED` false, the default. The client will explicitly explain that secure iOS verification isn't active; do not bypass this.
4. When the Apple server-side certificate and assertion verifiers have been implemented, reviewed and tested on physical devices, enable it only for signed builds:

```bash
flutter build ipa --release --dart-define=IOS_ATTEST_ENABLED=true
```

Do not distribute this app as a working iOS serial verifier before all checks pass.
