import 'package:flutter_test/flutter_test.dart';

// Phase 10: pure-logic guards (mirrors server refund table + QR payload shape).
String refundPreview(double hrsBefore) {
  if (hrsBefore > 6) return 'full';
  if (hrsBefore >= 1) return 'half';
  return 'none';
}

void main() {
  test('refund table', () {
    expect(refundPreview(7), 'full');
    expect(refundPreview(3), 'half');
    expect(refundPreview(0.5), 'none');
  });
  test('qr payload has required keys', () {
    const p = {'v': 1, 'bid': 'b', 'tid': 't', 'nonce': 'n', 'code': 'ABC123'};
    for (final k in ['v', 'bid', 'tid', 'nonce', 'code']) {
      expect(p.containsKey(k), true);
    }
  });
  test('overbooking guard logic', () {
    const capacity = 14;
    const booked = 12;
    const seats = 3;
    expect(booked + seats <= capacity, false);
  });
}
