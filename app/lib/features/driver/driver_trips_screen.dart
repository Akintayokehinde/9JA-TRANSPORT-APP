import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/network/functions_client.dart';
import '../../core/storage/hive_boxes.dart';
import '../../core/tracking/tracking_service.dart';
import '../verify/trip_queue_screen.dart';

/// Phase 7 hardened: today trips (tap → queue), per-trip pax/paid/unpaid,
/// earnings detail (gross − 3% charge = net), pull-to-refresh + Hive offline cache.
class DriverTripsScreen extends StatefulWidget {
  const DriverTripsScreen({super.key});
  @override
  State<DriverTripsScreen> createState() => _DriverTripsScreenState();
}

class _DriverTripsScreenState extends State<DriverTripsScreen> {
  final api = FunctionsClient();
  final tracking = TrackingService();
  List trips = [];
  Map? earnings;
  List perTrip = [];
  bool loading = true;
  bool offline = false;

  @override
  void dispose() {
    tracking.stop();
    super.dispose();
  }

  @override
  void initState() { super.initState(); _load(); }

  String naira(dynamic kobo) => '₦${((int.tryParse(kobo.toString()) ?? 0) / 100).toStringAsFixed(0)}';

  Future<void> _togglePing(String tripId) async {
    try {
      if (tracking.tripId == tripId) {
        await tracking.stop();
      } else {
        await tracking.stop();
        await tracking.start(tripId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🛰 Sharing live location with booked passengers')));
        }
      }
      setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _mark(String tripId, String to) async {
    await api.markTripStatus(tripId, to);
    if (to == 'completed' || to == 'cancelled') await tracking.stop(); // pings stop at trip end
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await api.driverTrips();
      final e = await api.driverEarnings();
      final list = List.from(t['trips'] ?? []);
      setState(() {
        trips = list;
        earnings = Map.from(e['earnings'] as Map);
        perTrip = List.from(e['perTrip'] ?? []);
        loading = false; offline = false;
      });
      await Hive.box(HiveBoxes.tripsCache).put('driver_today', list);
    } catch (_) {
      final cached = Hive.box(HiveBoxes.tripsCache).get('driver_today', defaultValue: []);
      setState(() { trips = List.from(cached); loading = false; offline = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Driver — Today')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (offline) Container(padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
            child: const Text('📴 Offline — showing saved trips', style: TextStyle(color: Color(0xFFFFC300)))),
          if (earnings != null) Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Today's earnings", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 4),
              Text('Completed: ${earnings!['completed']} · Pax: ${earnings!['pax']} · Bookings: ${earnings!['bookings']}'),
              Text('Online ${naira(earnings!['online_kobo'])} · Cash ${naira(earnings!['cash_kobo'])}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('Gross ${naira(earnings!['gross_kobo'])} − charge ${naira(earnings!['charge_kobo'])} (3%) = Net ${naira(earnings!['net_kobo'])}',
                style: const TextStyle(fontWeight: FontWeight.w800)),
              const Text('Charge rate confirmable at pilot (§38).', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ]))),
          const SizedBox(height: 8),
          const Text('My trips — tap for passenger queue', style: TextStyle(fontWeight: FontWeight.w800)),
          ...trips.map((e) {
            final t = Map<String, dynamic>.from(e as Map);
            final detail = perTrip.cast<Map>().firstWhere(
              (p) => Map<String, dynamic>.from(p as Map)['id'].toString() == t['id'].toString(),
              orElse: () => <String, dynamic>{});
            final dm = detail.isEmpty ? null : Map<String, dynamic>.from(detail);
            return Card(child: ListTile(
              title: Text("${t['from_park']} → ${t['to_park']}", style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${t['departs_at']} · Booked ${t['booked_count']} · Arrived ${t['arrived_count']} · ${t['status']}'
                '${dm == null ? '' : '\nPax ${dm['pax']} · ${naira(dm['gross_kobo'])} · Unpaid ${dm['unpaid_count']}'}'),
              isThreeLine: true,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) =>
                TripQueueScreen(tripId: t['id'].toString(), title: "${t['from_park']} → ${t['to_park']}"))),
              trailing: t['status'] == 'departed'
                  ? IconButton(
                      icon: Icon(
                        tracking.tripId == t['id'].toString() ? Icons.location_on : Icons.location_off,
                        color: tracking.tripId == t['id'].toString() ? const Color(0xFF0A7A3B) : null),
                      tooltip: tracking.tripId == t['id'].toString() ? 'Sharing live location — tap to stop' : 'Share live location',
                      onPressed: () => _togglePing(t['id'].toString()),
                    )
                  : PopupMenuButton<String>(
                      onSelected: (v) => _mark(t['id'].toString(), v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'boarding', child: Text('Boarding')),
                  PopupMenuItem(value: 'ready_to_leave', child: Text('Ready')),
                  PopupMenuItem(value: 'departed', child: Text('Depart')),
                  PopupMenuItem(value: 'completed', child: Text('Complete')),
                ],
              ),
            ));
          }),
          if (trips.isEmpty) const Text('No trips assigned today.'),
        ]),
      ),
    );
  }
}
