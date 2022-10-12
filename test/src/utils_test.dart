import 'package:flutter_test/flutter_test.dart';
import 'package:sbt_auth_dart/src/utils.dart';

void main() {
  group('test utils', () {
    test('should return correct ether amount in we', () {
      final expected = BigInt.parse('15');
      const value = '15e-18';
      final actual = parseUnit(value);
      expect(expected, actual);
    });
    test('should return correct ether amount in wei with a weird ether amount',
        () async {
      final expected = BigInt.parse('1000000101010109000000');
      const value = '1000.000101010109';
      final actual = parseUnit(value);
      expect(actual, expected);
    });

    test('convert bigint to hex string', () {
      const expected = '0x10';
      final value = BigInt.from(16);
      final actual = bigIntToHex(value);
      expect(actual, expected);
    });
  });
}
