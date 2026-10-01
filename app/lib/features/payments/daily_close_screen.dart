import 'package:flutter/material.dart';
import '../../core/network/functions_client.dart';

/// Phase 8: end-of-day cash reconciliation (worker/admin, park-scoped).
/// Paid vs unpaid vs cash-collected vs outstanding — compare with physical cash.
class DailyCloseScreen extends StatefulWidget {
  const DailyCloseScreen({super.key});
  @override
  State<DailyCloseScreen> createState() => _DailyCloseScreenState();
}

class _DailyCloseScreenState extends State<DailyCloseScreen> {
  final api = FunctionsClient();
  Map? close;
  bool loading = true;

  @override
  void initState() { super.initState(); _load(); }

  String n(dynamic k) => '₦${((int.tryParse(k.toString()) ?? 0) / 100).toStringAsFixed(0)}';

  Future<void> _load() async {
    try {
      final r = await api.dailyClose();
      setState(() { close = Map.from(r['close'] as Map); loading = false; });
    } catch (e) {
      setState(() => loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily close')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : close == null
              ? const Center(child: Text('No data'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text("Today's takings", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                        const SizedBox(height: 6),
                        _row('Paid bookings', '${close!['paid_count']}'),
                        _row('Unpaid (cash due)', '${close!['unpaid_count']}'),
                        const Divider(),
                        _row('Collected', n(close!['collected_kobo'])),
                        _row('Of which cash', n(close!['cash_kobo'])),
                        _row('Outstanding', n(close!['outstanding_kobo'])),
                      ]))),
                    const Text('Count physical cash against "Of which cash". Outstanding = to collect before departures.',
                      style: TextStyle(color: Color(0xFF6B7280))),
                  ]),
                ),
    );
  }

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(k), Text(v, style: const TextStyle(fontWeight: FontWeight.w800)),
    ]),
  );
}
