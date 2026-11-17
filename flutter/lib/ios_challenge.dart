/// Shared parsing for server-issued Apple App Attest challenges.
///
/// These checks are client-side safeguards. The backend independently enforces
/// expiration, one-time consumption, and cryptographic proof verification.
typedef HmcIosChallenge = ({String id, String nonce});

HmcIosChallenge parseIosChallenge(
  Map<String, dynamic> input, {
  DateTime? now,
}) {
  final id = input['id'];
  final nonce = input['challenge'];
  final expires = input['expires_at'];
  final expiration = DateTime.tryParse(expires is String ? expires : '');
  final uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  if (id is! String || !uuid.hasMatch(id) ||
      nonce is! String || nonce.length < 16 || nonce.length > 512 ||
      expiration == null ||
      !expiration.toUtc().isAfter((now ?? DateTime.now()).toUtc())) {
    throw const FormatException('Invalid or expired HMC iOS challenge');
  }
  return (id: id, nonce: nonce);
}
