import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/network/functions_client.dart';

/// Phase 8 hardened: provider toggle (Paystack primary, Flutterwave fallback).
/// Init opens the checkout link in browser; verify confirms server-side.
class PaymentScreen extends StatefulWidget {
  final String bookingId;
  const PaymentScreen({super.key, required this.bookingId});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final api = FunctionsClient();
  final email = TextEditingController();
  final ref = TextEditingController();
  String provider = 'paystack';
  String? url;
  bool busy = false;

  Future<void> _init() async {
    setState(() => busy = true);
    try {
      late Map<String, dynamic> r;
      if (provider == 'paystack') {
        r = await api.paystackInit(bookingId: widget.bookingId,
          email: email.text.trim().isEmpty ? null : email.text.trim());
        setState(() {
          url = r['authorizationUrl'] as String;
          ref.text = r['reference'] as String? ?? '';
        });
      } else {
        r = await api.flutterwaveInit(bookingId: widget.bookingId,
          email: email.text.trim().isEmpty ? null : email.text.trim());
        setState(() {
          url = r['link'] as String;
          ref.text = r['txRef'] as String? ?? '';
        });
      }
      final uri = Uri.parse(url!);
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      setState(() => busy = false);
    }
  }

  Future<void> _verify() async {
    if (ref.text.trim().isEmpty) return;
    setState(() => busy = true);
    try {
      if (provider == 'paystack') {
        await api.verifyPaystack(reference: ref.text.trim(), bookingId: widget.bookingId);
      } else {
        // Flutterwave returns transaction_id on redirect; paste it here in test mode.
        await api.verifyFlutterwave(transactionId: ref.text.trim(), bookingId: widget.bookingId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment verified — booking paid')));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pay Now (test)')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Pay with:', style: TextStyle(fontWeight: FontWeight.w700)),
        Row(children: [
          Expanded(child: RadioListTile(value: 'paystack', groupValue: provider,
            title: const Text('Paystack'), onChanged: (v) => setState(() { provider = v!; url = null; }))),
          Expanded(child: RadioListTile(value: 'flutterwave', groupValue: provider,
            title: const Text('Flutterwave'), onChanged: (v) => setState(() { provider = v!; url = null; }))),
        ]),
        TextField(controller: email, keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email for receipt', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        ElevatedButton(onPressed: busy ? null : _init,
          child: Text(busy ? 'Working…' : 'Pay with ${provider == 'paystack' ? 'Paystack' : 'Flutterwave'}')),
        if (url != null) ...[
          const SizedBox(height: 8),
          const Text('Checkout opened in browser. Complete payment there, then verify below.',
            style: TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          TextField(controller: ref, decoration: InputDecoration(
            labelText: provider == 'paystack' ? 'Paystack reference (auto-filled)' : 'Flutterwave transaction ID',
            border: const OutlineInputBorder())),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: busy ? null : _verify, child: const Text('I paid — Verify')),
          TextButton(onPressed: () async {
            final uri = Uri.parse(url!);
            if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
          }, child: const Text('Re-open checkout')),
        ],
        const SizedBox(height: 12),
        const Text('Reserve path: pay cash at park — worker taps Cash received.',
          style: TextStyle(color: Color(0xFF6B7280))),
      ]),
    );
  }
}
