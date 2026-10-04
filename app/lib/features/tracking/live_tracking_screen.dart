import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart';
import '../../core/network/functions_client.dart';

// Google Maps when a key is supplied at build time
//   flutter run --dart-define=GOOGLE_MAPS_KEY=AIza...
// otherwise free OSM tiles via flutter_map (no key, pilot default).
const _gKey = String.fromEnvironment('GOOGLE_MAPS_KEY');
bool get _useGoogle => _gKey.isNotEmpty;

/// Phase 12: passenger live view — bus icon, ETA, stale handling.
/// Polls every 15s; only available while trip is active (server enforces).
class LiveTrackingScreen extends StatefulWidget {
  final String tripId;
  final String title;
  const LiveTrackingScreen({super.key, required this.tripId, required this.title});
  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final api = FunctionsClient();
  final mapCtl = MapController();
  Timer? _poll;
  Map? pos;
  Map? trip;
  bool? stale;
  int? ageSec;
  int? etaMin;
  String? error;
  bool mapFailed = false;

  @override
  void initState() {
    super.initState();
    _fetch();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _fetch());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final r = await api.getTripLocation(widget.tripId);
      if (!mounted) return;
      setState(() {
        trip = r['trip'] == null ? null : Map.from(r['trip'] as Map);
        pos = r['position'] == null ? null : Map.from(r['position'] as Map);
        stale = r['stale'] as bool?;
        ageSec = (r['ageSec'] as num?)?.toInt();
        etaMin = (r['etaMin'] as num?)?.toInt();
        error = null;
      });
      if (pos != null) {
        mapCtl.move(LatLng((pos!['lat'] as num).toDouble(), (pos!['lng'] as num).toDouble()), 13);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStale = stale ?? true;
    return Scaffold(
      appBar: AppBar(title: Text('🚌 ${widget.title}')),
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: isStale ? const Color(0xFF6B7280) : const Color(0xFF0A7A3B),
          child: Text(
            pos == null
                ? 'Waiting for first ping from driver…'
                : isStale
                    ? 'Last known location · seen ${ageSec ?? '?'}s ago — bus may have lost signal'
                    : '● Bus moving · ETA ${etaMin == null ? '…' : '$etaMin min'} · In transit',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: pos == null
              ? const Center(child: Text('No position yet. Tracking starts when the bus departs.'))
              : mapFailed
                  ? Center(child: Text(
                      'Map tiles need internet.\nBus last seen at ${pos!['lat']}, ${pos!['lng']}',
                      textAlign: TextAlign.center))
                      : Stack(
                          children: [
                            _useGoogle
                                ? _GoogleBusMap(
                                    lat: (pos!['lat'] as num).toDouble(),
                                    lng: (pos!['lng'] as num).toDouble(),
                                    dimmed: isStale,
                                  )
                                : FlutterMap(
                                mapController: mapCtl,
                                options: MapOptions(
                                  initialCenter: LatLng((pos!['lat'] as num).toDouble(), (pos!['lng'] as num).toDouble()),
                                  initialZoom: 13,
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    errorTileCallback: (_, __) { if (!mapFailed) setState(() => mapFailed = true); },
                                  ),
                                  // Planned route (static corridor, same shape as backend park coords).
                                  PolylineLayer(polylines: [
                                    Polyline(
                                      points: const [
                                        LatLng(6.6018, 3.3515), LatLng(6.5785, 3.3685),
                                        LatLng(6.5520, 3.3790), LatLng(6.5050, 3.3880),
                                        LatLng(6.4620, 3.3935), LatLng(6.4458, 3.3958),
                                      ],
                                      strokeWidth: 4, color: const Color(0xFFFFC300),
                                    ),
                                  ]),
                                  MarkerLayer(markers: [
                                    Marker(
                                      point: LatLng((pos!['lat'] as num).toDouble(), (pos!['lng'] as num).toDouble()),
                                      width: 72, height: 72,
                                      // The moving vehicle is always the danfo bus: one shared
                                      // trips.last_* position, so every booked passenger sees
                                      // the same bus at the same spot.
                                      child: Opacity(
                                        opacity: isStale ? 0.45 : 1.0,
                                        child: SvgPicture.asset(
                                          'assets/danfo_bus.svg',
                                          placeholderBuilder: (_) =>
                                            const Text('🚌', style: TextStyle(fontSize: 36)),
                                        ),
                                      ),
                                    ),
                                  ]),
                                ],
                              ),
                            // Reference-style info card over the map: trip, status, schedule, actions.
                            Positioned(
                              left: 12, right: 12, bottom: 12,
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(widget.title,
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isStale
                                                  ? const Color(0xFF6B7280)
                                                  : const Color(0xFFDCFAE6),
                                              borderRadius: BorderRadius.circular(999)),
                                            child: Text(
                                              isStale ? 'Last known location' : 'On the way to location',
                                              style: TextStyle(
                                                fontSize: 12, fontWeight: FontWeight.w800,
                                                color: isStale ? Colors.white : const Color(0xFF0A7A3B)),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Schedule: ${trip?['departs_at'] ?? '—'} · ETA ${etaMin == null ? '…' : '$etaMin min'}',
                                        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                                      const SizedBox(height: 8),
                                      Row(children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: null, // wired to driver phone at pilot (tripDetail.driver_phone)
                                            icon: const Icon(Icons.call, size: 16),
                                            label: const Text('Call')),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => Navigator.of(context).maybePop(),
                                            icon: const Icon(Icons.receipt_long, size: 16),
                                            label: const Text('Details')),
                                        ),
                                      ]),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
        ),
        if (error != null)
          Padding(padding: const EdgeInsets.all(8),
            child: Text(error!, style: const TextStyle(color: Color(0xFFD92D20), fontSize: 12))),
        Padding(padding: const EdgeInsets.all(8),
          child: Text(
            _useGoogle ? 'Google Maps · live' : 'OpenStreetMap · free, no key (set GOOGLE_MAPS_KEY for Google)',
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12), textAlign: TextAlign.center)),
        const Padding(padding: const EdgeInsets.all(8),
          child: Text('Tracking stops automatically when the trip ends. Only booked passengers can see this bus.',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 12), textAlign: TextAlign.center)),
      ]),
    );
  }
}

/// Google-Maps variant of the bus marker (danfo asset as bitmap descriptor
/// would need platform channels — emoji pin keeps this dependency-free).
class _GoogleBusMap extends StatelessWidget {
  final double lat, lng;
  final bool dimmed;
  const _GoogleBusMap({required this.lat, required this.lng, required this.dimmed});
  @override
  Widget build(BuildContext context) {
    return gmaps.GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(target: gmaps.LatLng(lat, lng), zoom: 14),
      markers: {
        gmaps.Marker(
          markerId: const gmaps.MarkerId('danfo'),
          position: gmaps.LatLng(lat, lng),
          alpha: dimmed ? 0.45 : 1.0,
        ),
      },
      myLocationEnabled: false,
    );
  }
}
