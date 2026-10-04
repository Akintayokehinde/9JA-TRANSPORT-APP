import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/network/functions_client.dart';

/// Bank Card flow: enter card → review details → Pay → driver confirms at park
/// → slip becomes paid. Full PAN never leaves the Paystack checkout in production;
/// here only the last-4 is recorded with the pending attempt.
class CardPaymentScreen extends StatefulWidget {
  final String bookingId;
  final String bookingRef;
  final int amountKobo;
  const CardPaymentScreen({super.key, required this.bookingId, required this.bookingRef, required this.amountKobo});
  @override
  State<CardPaymentScreen> createState() => _CardPaymentScreenState();
}

class _CardPaymentScreenState extends State<CardPaymentScreen> {
  final api = FunctionsClient();
  final num = TextEditingController();
  final exp = TextEditingController();
  final cvv = TextEditingController();
  final name = TextEditingController();
  int step = 0; // 0 form, 1 review, 2 pending
  bool busy = false;
  String? error;
  String last4 = '';

  String get naira => '₦${(widget.amountKobo / 100).toStringAsFixed(0)}';

  static bool luhn(String digits) {
    if (digits.length < 15 || digits.length > 19) return false;
    int sum = 0;
    bool alt = false;
    for (int i = digits.length - 1; i >= 0; i--) {
      int d = digits.codeUnitAt(i) - 48;
      if (alt) { d *= 2; if (d > 9) d -= 9; }
      sum += d;
      alt = !alt;
    }
    return sum % 10 == 0;
  }

  static bool expiryOk(String v) {
    final m = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(v.trim());
    if (m == null) return false;
    final mm = int.parse(m.group(1)!);
    final yy = 2000 + int.parse(m.group(2)!);
    if (mm < 1 || mm > 12) return false;
    final now = DateTime.now();
    return yy > now.year || (yy == now.year && mm >= now.month);
  }

  void _toReview() {
    final digits = num.text.replaceAll(RegExp(r'\D'), '');
    if (!luhn(digits)) return setState(() => error = 'Enter a valid card number');
    if (!expiryOk(exp.text)) return setState(() => error = 'Expiry must be MM/YY in the future');
    if (!RegExp(r'^\d{3,4}$').hasMatch(cvv.text.trim())) return setState(() => error = 'Enter the 3–4 digit CVV');
    if (name.text.trim().isEmpty) return setState(() => error = 'Enter the name on card');
    setState(() { last4 = digits.substring(digits.length - 4); error = null; step = 1; });
  }

  Future<void> _pay() async {
    setState(() { busy = true; error = null; });
    try {
      await api.cardAttempt(bookingId: widget.bookingId, last4: last4);
      setState(() => step = 2);
    } catch (e) {
      setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bank Card')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (error != null)
          Container(padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: const Color(0xFFFEE4E2), borderRadius: BorderRadius.circular(8)),
            child: Text(error!, style: const TextStyle(color: Color(0xFFD92D20)))),
        if (step == 0) ...[
          const Text('Enter card details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(controller: num, keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(19)],
            decoration: const InputDecoration(labelText: 'Card number', hintText: '4084 0840 8408 4081', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: exp,
              inputFormatters: [LengthLimitingTextInputFormatter(5)],
              decoration: const InputDecoration(labelText: 'Expiry MM/YY', border: OutlineInputBorder()))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: cvv, keyboardType: TextInputType.number, obscureText: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
              decoration: const InputDecoration(labelText: 'CVV', border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 10),
          TextField(controller: name, textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name on card', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _toReview, child: const Text('Continue')),
        ] else if (step == 1) ...[
          const Text('Confirm payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
            _row('Booking', widget.bookingRef),
            _row('Amount', naira),
            _row('Card', '•••• •••• •••• $last4'),
            _row('Expiry', exp.text.trim()),
          ]))),
          const Text('Check the details above. After you press Pay, the driver confirms at the park — then your slip turns paid.',
            style: TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: busy ? null : _pay, child: Text(busy ? 'Sending…' : 'Pay $naira')),
          TextButton(onPressed: () => setState(() => step = 0), child: const Text('Back — edit card')),
        ] else ...[
          const Icon(Icons.hourglass_top, size: 56, color: Color(0xFFF79009)),
          const SizedBox(height: 8),
          const Text('Waiting for driver confirmation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text('Booking ${widget.bookingRef} · card •••• $last4 · $naira.\nShow this booking at the park — the driver taps Confirm, then your slip turns paid.',
            style: const TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Done')),
        ],
      ]),
    );
  }

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(k, style: const TextStyle(color: Color(0xFF6B7280))), Text(v, style: const TextStyle(fontWeight: FontWeight.w800))]),
  );
}
