/// Public application configuration only. Never store any service-role key,
/// Google service-account private key, Apple private key, or database secret here.
class HmcConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL',
          defaultValue: 'https://obloojlkjnagpdokofgw.supabase.co');
  static const googleCloudProjectNumber =
      String.fromEnvironment('GOOGLE_CLOUD_PROJECT_NUMBER');

  // Enable ONLY after backend checks Apple root cert, team/bundle ID, nonce,
  // signature, counter and one-time challenge on real production devices.
  static const iosAttestationEnabled =
      bool.fromEnvironment('IOS_ATTEST_ENABLED', defaultValue: false);

  static bool get isConfigured =>
      supabaseUrl.startsWith('https://') &&
      googleCloudProjectNumber.isNotEmpty;
}
