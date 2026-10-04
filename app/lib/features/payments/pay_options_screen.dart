import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/network/functions_client.dart';
import 'card_payment_screen.dart';

/// Pay Now → choose how: Paystack (card/transfer/USSD), Bank Card (card-only
/// Paystack channel), or 9JA Wallet balance. predeceases slip screen.
class PayOptionsScreen extends StatefulWidget {
  final String bookingId;
  final int amountKobo;
  const PayOptionsScreen({super.key, required this.bookingId, required this.amountKobo});
  @override
  State<PayOptionsScreen> createState() => _PayOptionsScreenState();
}

class _PayOptionsScreenState extends State<PayOptionsScreen> {
  final api = FunctionsClient();
  final email = TextEditingController();
  final ref = TextEditingController();
  int walletKobo = 0;
  bool loadingBal = true;
  String? url;
  String method = 'paystack'; // paystack | card | wallet
  bool busy = false;

  @override
  void initState() {
    super.initState();
    api.walletBalance().then((b) {
      if (mounted) setState(() { walletKobo = b; loadingBal = false; });
    }).catchError((_) {
      if (mounted) setState(() => loadingBal = false);
    });
  }

  String get naira => '₦${(widget.amountKobo / 100).toStringAsFixed(0)}';
  String get wNaira => '₦${(walletKobo / 100).toStringAsFixed(0)}';

  Future<void> _onlineInit() async {
    setState(() { busy = true; url = null; });
    try {
      final r = method == 'card'
          ? await api.paystackInitCard(bookingId: widget.bookingId,
              email: email.text.trim().isEmpty ? null : email.text.trim())
          : await api.paystackInit(bookingId: widget.bookingId,
              email: email.text.trim().isEmpty ? null : email.text.trim());
      setState(() {
        url = r['authorizationUrl'] as String;
        ref.text = r['reference'] as String? ?? '';
      });
      final uri = Uri.parse(url!);
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      setState(() => busy = false);
    }
  }

  Future<void> _onlineVerify() async {
    if (ref.text.trim().isEmpty) return;
    setState(() => busy = true);
    try {
      await api.verifyPaystack(reference: ref.text.trim(), bookingId: widget.bookingId);
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

  Future<void> _payWallet() async {
    setState(() => busy = true);
    try {
      await api.payWithWallet(widget.bookingId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paid from 9JA wallet')));
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
    final short = walletKobo < widget.amountKobo;
    return Scaffold(
      appBar: AppBar(title: Text('Pay $naira')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _opt('paystack', 'Paystack', 'Card, bank transfer, USSD — Paystack checkout',
            Icons.payment),
        _opt('card', 'Bank Card', 'Card only, same secure Paystack checkout', Icons.credit_card),
        _opt('wallet',
            'Wallet (9JA transport wallet)',
            loadingBal ? 'Checking balance…' : 'Balance $wNaira${short ? ' — too low, fund wallet first' : ''}',
            Icons.account_balance_wallet),
        const SizedBox(height: 8),
        if (method == 'wallet') ...[
          ElevatedButton(
            onPressed: (busy || short) ? null : _payWallet,
            child: Text(busy ? 'Paying…' : 'Pay $naira from wallet')),
          if (short && !loadingBal)
            const Text('Insufficient balance — fund your wallet from the Dashboard.',
              style: TextStyle(color: Color(0xFFD92D20))),
        ] else if (method == 'card') ...[
          const Text('Enter your card, review the details, then the driver confirms at the park.',
            style: TextStyle(color: Color(0xFF6B7280))),
          ElevatedButton(
            onPressed: busy ? null : () async {
              final done = await Navigator.of(context).push(MaterialPageRoute(builder: (_) =>
                CardPaymentScreen(bookingId: widget.bookingId,
                  bookingRef: widget.bookingId.length > 8 ? widget.bookingId.substring(0, 8) : widget.bookingId,
                  amountKobo: widget.amountKobo)));
              if (done == true && mounted) Navigator.of(context).pop(true);
            },
            child: const Text('Continue to card payment')),
        ] else ...[
          TextField(controller: email, keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email for receipt', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: busy ? null : _onlineInit,
            child: Text(busy ? 'Working…' : 'Continue to ${method == 'card' ? 'card payment' : 'Paystack'}')),
          if (url != null) ...[
            const SizedBox(height: 8),
            const Text('Checkout opened in browser. Complete payment there, then verify below.',
              style: TextStyle(color: Color(0xFF6B7280))),
            const SizedBox(height: 8),
            TextField(controller: ref, decoration: const InputDecoration(
              labelText: 'Payment reference (auto-filled)', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: busy ? null : _onlineVerify, child: const Text('I paid — Verify')),
          ],
        ],
      ]),
    );
  }

  Widget _opt(String v, String t, String s, IconData ic) => Card(
    color: method == v ? const Color(0xFFFFF8E1) : null,
    child: RadioListTile(
      value: v, groupValue: method, onChanged: (x) => setState(() { method = x!; url = null; }),
      title: Row(children: [Icon(ic), const SizedBox(width: 8), Text(t, style: const TextStyle(fontWeight: FontWeight.w800))]),
      subtitle: Text(s),
    ),
  );
}
