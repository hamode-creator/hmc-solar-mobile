import 'package:flutter_test/flutter_test.dart';
import 'package:hmc_solar_verify/ios_challenge.dart';

void main() {
  const uuid = '5a1bc073-b539-4e03-92d6-36ffb173ac39';
  const nonce = 'a9b8c7d6e5f400112233445566778899';
  final now = DateTime.utc(2026, 11, 11, 12);

  Map<String, dynamic> challenge({Object? id = uuid, Object? value = nonce,
      Object? expires = '2026-11-11T12:02:00Z'}) => {
    'id': id, 'challenge': value, 'expires_at': expires,
  };

  test('accepts a well formed, unexpired nonce', () {
    final data = parseIosChallenge(challenge(), now: now);
    expect(data.id, uuid);
    expect(data.nonce, nonce);
  });
  test('rejects expired and missing expiry', () {
    expect(() => parseIosChallenge(challenge(expires: '2026-11-11T11:59:59Z'), now: now), throwsFormatException);
    expect(() => parseIosChallenge(challenge(expires: null), now: now), throwsFormatException);
  });
  test('rejects altered or missing challenge IDs', () {
    expect(() => parseIosChallenge(challenge(id: 'bad-id'), now: now), throwsFormatException);
    expect(() => parseIosChallenge(challenge(id: null), now: now), throwsFormatException);
  });
  test('rejects short, long and malformed nonce values', () {
    expect(() => parseIosChallenge(challenge(value: '123'), now: now), throwsFormatException);
    expect(() => parseIosChallenge(challenge(value: List.filled(513, 'a').join()), now: now), throwsFormatException);
    expect(() => parseIosChallenge(challenge(value: null), now: now), throwsFormatException);
  });
}
