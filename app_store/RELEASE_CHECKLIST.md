# HMC Solar — iOS App Store release checklist

## Verified in this project
- Bundle ID: `com.hmcsolar.verify`.
- Release version currently built and tested through TestFlight: `0.3.2 (8)`.
- Public app verifies whether a serial is recorded as **sold by HMC Solar**, without login.
- Arabic and English UI; manual entry, paste, barcode/QR camera scan.
- Successful verification is **not** a manufacturer authenticity or warranty certification.
- Server uses Apple App Attest and one-time challenge verification; no service-role secret is shipped in the app.
- Real iPhone verification with the production Supabase backend was reported successful.
- Android release work is deferred. Do not modify Play Integrity or Android build settings for this launch.

## Confirm in App Store Connect before pressing Submit for Review
- Select the existing Build 8 only if its status is eligible for App Store review.
- App information: app name, primary language, category, age rating, support URL and rights.
- Product page: concise app description, keywords, screenshots taken from the real iPhone app, and any required iPad assets if the signed build supports iPad.
- App privacy: a publicly accessible company privacy-policy URL and accurate App Privacy answers. Review actual processing of serials, challenge/attestation data, rate-limiting identifiers, server logs, and third-party SDKs. Do **not** assume “Data Not Collected.”
- Export compliance for the selected build.
- App Review contact information and review notes explaining how to test the **sold** and **not sold** paths without exposing real customer inventory.
- Pricing/availability and any required business/financial agreements.
- Confirm the correct release option (manual release is safer for the initial launch).

## Safety controls
- Never submit automatically from Codemagic. The `hmc-ios-signed` workflow uploads to App Store Connect with `submit_to_app_store: false`.
- Do not use the Staging TestFlight workflow for an App Store release.
- Do not expose production serials, customer identities, service-role keys, or Apple private material in App Review notes or public repository files.
- Keep previous Android verification service available; testing Android is deliberately deferred.
