import 'package:flutter/material.dart';
import '../../core/network/functions_client.dart';

/// Phase 6: booking queue per trip (PRD §22) — arrived first, then waiting.
/// Example: 001 Arrived · 002 Arrived · 003 Waiting. Tap cash badge → mark cash.
class TripQueueScreen extends StatefulWidget {
  final String tripId;
  final String title;
  const TripQueueScreen({super.key, required this.tripId, required this.title});
  @override
  State<TripQueueScreen> createState() => _TripQueueScreenState();
}

class _TripQueueScreenState extends State<TripQueueScreen> {
  final api = FunctionsClient();
  List queue = [];
  Map? trip;
  bool loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await api.tripBookings(widget.tripId);
      setState(() {
        queue = List.from(res['bookings'] ?? []);
        trip = res['trip'] == null ? null : Map.from(res['trip'] as Map);
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final arrived = queue.where((e) =>
      ['arrived', 'boarded'].contains((Map<String, dynamic>.from(e as Map))['booking_status'])).length;
    return Theme(
      data: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title), backgroundColor: Colors.black),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  Text('Booked ${queue.length} · Arrived $arrived · Waiting ${queue.length - arrived}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                  const SizedBox(height: 8),
                  ...queue.asMap().entries.map((en) {
                    final b = Map<String, dynamic>.from(en.value as Map);
                    final isArrived = ['arrived', 'boarded'].contains(b['booking_status']);
                    final paid = b['payment_status'] == 'paid';
                    return Card(
                      color: isArrived ? const Color(0xFF0A3D22) : const Color(0xFF1F1F1F),
                      child: ListTile(
                        leading: Text('${(en.key + 1).toString().padLeft(3, '0')}',
                          style: const TextStyle(color: Color(0xFFFFC300), fontWeight: FontWeight.w800)),
                        title: Text('${b['passenger_name']} ×${b['seats']}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        subtitle: Text('${b['booking_no']} · ${isArrived ? 'Arrived' : 'Waiting'} · ${paid ? 'paid' : 'UNPAID cash'}',
                          style: const TextStyle(color: Colors.grey)),
                        trailing: paid
                            ? const Icon(Icons.check_circle, color: Color(0xFF0A7A3B))
                            : TextButton(
                                onPressed: () async {
                                  await FunctionsClient().markCashReceived(b['id'].toString());
                                  _load();
                                },
                                child: const Text('Cash?', style: TextStyle(color: Color(0xFFFFC300)))),
                      ),
                    );
                  }),
                  if (queue.isEmpty) const Text('No active bookings on this trip.',
                    style: TextStyle(color: Colors.grey)),
                ]),
              ),
      ),
    );
  }
}
