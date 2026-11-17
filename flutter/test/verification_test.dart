import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmc_solar_verify/main.dart';
import 'package:hmc_solar_verify/verify_service.dart';

void main() {
  test('serials are normalized identically to Supabase', () {
    expect(normalizeSerial(' ab-12 34-x '), 'AB1234X');
    expect(normalizeSerial('  deye/08:ab.1'), 'DEYE/08:AB.1');
    expect(isValidSerial('AB1234X'), isTrue);
    expect(isValidSerial('ABC'), isFalse);
    expect(isValidSerial(List.filled(81, 'X').join()), isFalse);
    expect(isValidSerial('ABC123!'), isFalse);
  });

  test('barcodes ignore URLs and accept labelled serials', () {
    expect(normalizeScannedSerial('S/N: abc-1234'), 'ABC1234');
    expect(normalizeScannedSerial('serial number = deye8901'), 'DEYE8901');
    expect(normalizeScannedSerial('https://example.com/ABC1234'), isNull);
    expect(normalizeScannedSerial('N/A'), isNull);
  });

  test('Google request binding changes with every request and serial', () {
    final a = boundRequestHash('id-a', 'challenge-a', 'ABC1234');
    final b = boundRequestHash('id-a', 'challenge-a', 'ABC1235');
    final c = boundRequestHash('id-b', 'challenge-a', 'ABC1234');
    expect(a.length, 43);
    expect(a, isNot(b));
    expect(a, isNot(c));
    expect(a.contains('='), isFalse);
    expect(
      boundRequestHash('5a1bc073-b539-4e03-92d6-36ffb173ac39',
          'a9b8c7d6e5f400112233445566778899', 'DEYE12345678'),
      'hzEhJRYVw-J5U2yVDd_19idCpDbDKfSckERfKmS6qEA',
    );
  });

  testWidgets('invalid serial is rejected without networking', (tester) async {
    await tester.pumpWidget(const HmcSolarApp());
    await tester.enterText(find.byType(TextField), 'bad!');
    await tester.tap(find.text('تحقق من السيريال'));
    await tester.pumpAndSettle();
    expect(find.textContaining('السيريال غير صحيح'), findsOneWidget);
  });
}
