// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:sbt_auth_dart/sbt_auth_dart.dart';

void main() {
  test('Generate address', () {
    const publicKey =
        '0x022f5329b55e25601a5ab7cefa6fd75437a013d8174559cb2cf45ee71e3f1fa323';
    const expectedAddress = 'TD7J8GZpBCe5GdoA3QCVDhpfS2myvRvHD9';
    final tronAddress = tronPublicKeyToAddress(publicKey);
    expect(tronAddress, expectedAddress);
  });
}
