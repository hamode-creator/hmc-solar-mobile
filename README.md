# HMC Solar — Customer Mobile App

Flutter customer-facing iOS/Android application for verifying HMC Solar equipment serial numbers.

**Source version:** 0.3.2, prepared for Codemagic validation on 2026-11-16.  
**iOS Bundle ID:** `com.hmcsolar.verify`  
**Apple App Store Connect record:** HMC Solar  
**Codemagic workflow:** `hmc-ios-validation` in `codemagic.yaml`.

## Current security status

- Device inventory remains in **Supabase**. This repository contains no database dump or private keys.
- The customer app does not include an admin dashboard or direct database access.
- The iOS App Attest client is scaffolded, but its **server-side certificate and assertion verifiers are not yet active**. The server rejects iOS verification requests. This is deliberate: never bypass verification to make a demo appear functional.
- `IOS_ATTEST_ENABLED` must remain `false` until the backend verifier has been reviewed and tested on a real iPhone.
- The included Codemagic workflow validates the app **without signing**. It will **not** upload an IPA to TestFlight yet.

## Build on Codemagic (no Mac needed)

1. Create a new GitHub repository named `hmc-solar-mobile` and upload the **contents** of this folder to its root. Do not upload the ZIP without extracting it.
2. In Codemagic, choose this repository and project type **Flutter**.
3. Select the `hmc-ios-validation` workflow from `codemagic.yaml` to run analysis, tests, and an unsigned iOS build.
4. After this passes, configure an App Store Connect API key **inside Codemagic** (not in GitHub); choose automatic iOS code signing for `com.hmcsolar.verify` and add a separate signed publishing workflow.
5. Complete the server-side Apple App Attest verifier before enabling live serial verification or advertising the TestFlight build as functional.

Never commit Apple API `.p8` files, signing certificates, Google service account JSON, or Supabase service-role keys. A public Supabase project URL is not a secret, but all privileged access must remain server-only.

## Application source

- `flutter/lib/`: app, scanner and integrity client code
- `flutter/assets/`: HMC logo and icons
- `flutter/test/`: Flutter unit and widget tests
- `flutter/prepare_native.py`: generates iOS/Android project files in CI
- `tests/`: source and native setup checks

## Important

This repository is **not yet a published application**. A successful unsigned iOS build confirms compilation only, not signed installation, TestFlight acceptance, or App Attest verification on a physical iPhone.
