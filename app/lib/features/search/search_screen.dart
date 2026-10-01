import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/network/functions_client.dart';
import '../../core/storage/hive_boxes.dart';
import '../booking/trip_detail_screen.dart';

/// Phase 4 gate screen 2: search seeded trips (Ikeja↔CMS). Caches to Hive.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final api = FunctionsClient();
  List trips = [];
  bool loading = false;
  String? error;

  // Pilot park ids from database/seed.sql
  static const ikeja = '11111111-1111-1111-1111-111111111111';
  static const cms = '22222222-2222-2222-2222-222222222222';

  Future<void> search() async {
    setState(() { loading = true; error = null; });
    try {
      final res = await api.searchTrips(fromParkId: ikeja, toParkId: cms, date: DateTime.now(), seats: 1);
      final list = List.from(res['trips'] ?? []);
      setState(() => trips = list);
      await Hive.box(HiveBoxes.tripsCache).put('last_search', list);
    } catch (e) {
      // Offline fallback: show cached
      final cached = Hive.box(HiveBoxes.tripsCache).get('last_search', defaultValue: []);
      setState(() { trips = List.from(cached); error = 'Offline — showing saved results'; });
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book a Ride')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          if (error != null)
            Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
              child: Text(error!, style: const TextStyle(color: Color(0xFFFFC300)))),
          ElevatedButton(onPressed: loading ? null : search,
            child: Text(loading ? 'Searching…' : 'Search Ikeja → CMS (today)')),
          const SizedBox(height: 12),
          Expanded(
            child: trips.isEmpty
                ? const Center(child: Text('No trips yet. Run seed.sql then search.'))
                : ListView.builder(
                    itemCount: trips.length,
                    itemBuilder: (_, i) {
                      final t = Map<String, dynamic>.from(trips[i] as Map);
                      final left = (t['capacity'] as int) - (t['booked_count'] as int);
                      return Card(child: ListTile(
                        title: Text('${t['from_park']} → ${t['to_park']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('${t['departs_at']} · ${t['vehicle_type'] ?? 'danfo'} · $left spaces left'),
                        trailing: Text('₦${((t['fare_kobo'] as int) / 100).toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => TripDetailScreen(tripId: t['id'].toString()))),
                      ));
                    }),
          ),
        ]),
      ),
    );
  }
}
