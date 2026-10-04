import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/network/functions_client.dart';
import '../support/support_screen.dart';

/// Passenger dashboard: profile details, wallet balance + fund, transactions, support.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final api = FunctionsClient();
  Map? user;
  int balance = 0;
  List txns = [];
  bool loading = true;
  bool funding = false;
  final fundAmt = TextEditingController(text: '2000');
  final fundRef = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  String n(dynamic k) => '₦${((int.tryParse(k.toString()) ?? 0) / 100).toStringAsFixed(0)}';

  Future<void> _load() async {
    try {
      final p = await api.myProfile();
      final h = await api.walletHistory();
      setState(() {
        user = p['user'] == null ? null : Map.from(p['user'] as Map);
        balance = int.parse(p['balanceKobo'].toString());
        txns = h;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _fundInit() async {
    final kobo = (int.tryParse(fundAmt.text.trim()) ?? 0) * 100;
    if (kobo < 10000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimum top-up is ₦100')));
      return;
    }
    setState(() => funding = true);
    try {
      final r = await api.topupInit(amountKobo: kobo);
      fundRef.text = r['reference'] as String? ?? '';
      final uri = Uri.parse(r['authorizationUrl'] as String);
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pay in browser, then tap "I funded — Verify"')));
        setState(() {});
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      setState(() => funding = false);
    }
  }

  Future<void> _fundVerify() async {
    if (fundRef.text.trim().isEmpty) return;
    setState(() => funding = true);
    try {
      await api.verifyPaystack(reference: fundRef.text.trim(), bookingId: '');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wallet funded')));
      _load();
    } catch (e) {
      // Top-up without bookingId: verify reads metadata, credits wallet.
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      setState(() => funding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final u = user ?? {};
    return Scaffold(
      appBar: AppBar(title: const Text('My Dashboard')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Profile', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text('${u['first_name'] ?? ''} ${u['last_name'] ?? ''} ${u['first_name'] == null ? '(no profile yet)' : ''}'
                .trim(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
              Text('@${u['username'] ?? '—'} · ${u['phone'] ?? ''} · ${u['email'] ?? ''}',
                style: const TextStyle(color: Color(0xFF6B7280))),
              Text('Email ${u['email_verified'] == true ? '✓' : '✗'} · Phone ${u['phone_verified'] == true ? '✓' : '✗'} · Trips ${u['trips_completed'] ?? 0}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ]))),
          Card(color: const Color(0xFFFFF8E1), child: Padding(
            padding: const EdgeInsets.all(14), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('9JA Wallet balance', style: TextStyle(fontWeight: FontWeight.w700)),
              Text(n(balance), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 30)),
              Row(children: [
                Expanded(child: TextField(controller: fundAmt, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount ₦ (min 100)', border: OutlineInputBorder()))),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: funding ? null : _fundInit, child: const Text('Fund')),
              ]),
              if (fundRef.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                TextField(controller: fundRef, decoration: const InputDecoration(
                  labelText: 'Top-up reference', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                ElevatedButton(onPressed: funding ? null : _fundVerify,
                  child: const Text('I funded — Verify')),
              ],
            ]))),
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Transaction history', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              if (txns.isEmpty) const Text('No wallet transactions yet.',
                style: TextStyle(color: Color(0xFF6B7280))),
              ...txns.map((e) {
                final t = Map<String, dynamic>.from(e as Map);
                final credit = t['kind'] == 'fund' || t['kind'] == 'refund';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(credit ? Icons.arrow_downward : Icons.arrow_upward,
                    color: credit ? const Color(0xFF0A7A3B) : const Color(0xFFD92D20)),
                  title: Text('${t['kind']} · ${n(t['amount_kobo'])}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${t['booking_no'] ?? t['reference'] ?? ''} · ${t['created_at'] ?? ''}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                );
              }),
            ]))),
          Card(child: ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text('Support', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Emergencies, complaints, ratings'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SupportScreen())),
          )),
        ]),
      ),
    );
  }
}
