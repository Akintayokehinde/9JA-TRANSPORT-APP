import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/network/functions_client.dart';
import '../../core/storage/hive_boxes.dart';
import '../tracking/live_tracking_screen.dart';

/// My Bookings + cancel with refund preview (PRD §10). Falls back to Hive slips offline.
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});
  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final api = FunctionsClient();
  List bookings = [];
  bool loading = true;
  bool offline = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await api.myBookings();
      setState(() { bookings = List.from(res['bookings'] ?? []); loading = false; });
    } catch (_) {
      final slips = Hive.box(HiveBoxes.slips).values.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      setState(() {
        bookings = slips.map((s) => {
          'id': s['bookingId'], 'booking_no': s['bookingNo'], 'booking_status': 'saved offline',
          'from_park': (s['trip'] as Map)['from_park'], 'to_park': (s['trip'] as Map)['to_park'],
          'departs_at': (s['trip'] as Map)['departs_at'], 'trip_code': s['tripCode'],
        }).toList();
        offline = true; loading = false;
      });
    }
  }

  String _refundPreview(Map b) {
    // Client preview only; server applies table. Uses departs_at.
    try {
      final hrs = DateTime.parse(b['departs_at'].toString()).difference(DateTime.now()).inMinutes / 60;
      if (hrs > 6) return 'Full refund (minus charge)';
      if (hrs >= 1) return '50% refund';
      return 'No refund';
    } catch (_) { return 'See cancel rules'; }
  }

  Future<void> _cancel(Map b) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Cancel booking?'),
      content: Text(_refundPreview(b)),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel booking'))],
    ));
    if (ok != true) return;
    try {
      final res = await api.cancelBooking(b['id'].toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cancelled · refund: ${res['refundKobo']} kobo')));
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('My Bookings')),
      body: Column(children: [
        if (offline) Container(width: double.infinity, padding: const EdgeInsets.all(10),
          color: Colors.black, child: const Text('📴 Offline — showing saved slips',
            style: TextStyle(color: Color(0xFFFFC300)))),
        Expanded(child: bookings.isEmpty
            ? const Center(child: Text('No bookings yet.'))
            : ListView.builder(itemCount: bookings.length, itemBuilder: (_, i) {
                final b = Map<String, dynamic>.from(bookings[i] as Map);
                final active = b['trip_status'] == 'departed';
                return Card(child: ListTile(
                  title: Text('${b['from_park']} → ${b['to_park']}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${b['booking_no']} · ${b['booking_status']} · ${b['departs_at']}\n${_refundPreview(b)}'),
                  isThreeLine: true,
                  trailing: active
                      ? ElevatedButton(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => LiveTrackingScreen(
                              tripId: b['trip_id'].toString(),
                              title: "${b['from_park']} → ${b['to_park']}"))),
                          child: const Text('Track 🚌'))
                      : (b['booking_status'] == 'reserved' || b['booking_status'] == 'paid')
                          ? TextButton(onPressed: () => _cancel(b), child: const Text('Cancel'))
                          : null,
                ));
              })),
      ]),
    );
  }
}
