import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/network/functions_client.dart';
import '../../core/storage/hive_boxes.dart';
import 'verify_result.dart';
import 'trip_queue_screen.dart';

/// Phase 6 hardened: torch toggle, haptics + color result, last-sync stamp,
/// pull-to-refresh counts, tap trip → queue (§22), offline queue auto-sync.
class ParkModeScreen extends StatefulWidget {
  const ParkModeScreen({super.key});
  @override
  State<ParkModeScreen> createState() => _ParkModeScreenState();
}

class _ParkModeScreenState extends State<ParkModeScreen> {
  final api = FunctionsClient();
  final codeCtrl = TextEditingController();
  List trips = [];
  bool loading = true;
  Map? lastResult;
  bool syncing = false;
  DateTime? lastSync;

  @override
  void initState() { super.initState(); _load(); _syncQueue(); }

  Future<void> _load() async {
    try {
      final res = await api.parkTrips();
      setState(() { trips = List.from(res['trips'] ?? []); loading = false; lastSync = DateTime.now(); });
    } catch (e) {
      setState(() => loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Trips load failed: $e')));
    }
  }

  Future<void> _syncQueue() async {
    final box = Hive.box(HiveBoxes.scanQueue);
    if (box.isEmpty) return;
    setState(() => syncing = true);
    for (final k in box.keys.toList()) {
      try {
        final p = Map<String, dynamic>.from(box.get(k) as Map);
        await api.verifyScan(bid: p['bid'], tid: p['tid'], nonce: p['nonce'], code: p['code']);
        await box.delete(k);
      } catch (_) { break; }
    }
    setState(() { syncing = false; lastSync = DateTime.now(); });
  }

  void _buzz(String result) {
    if (result == 'valid') {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.vibrate();
    }
    SystemSound.play(SystemSoundType.click);
  }

  Future<void> _verify({String? bid, String? tid, String? nonce, String? code}) async {
    try {
      final res = await api.verifyScan(bid: bid, tid: tid, nonce: nonce, code: code);
      _buzz(res['result'] as String);
      setState(() => lastResult = res);
      _load();
    } catch (_) {
      await Hive.box(HiveBoxes.scanQueue).add({'bid': bid, 'tid': tid, 'nonce': nonce, 'code': code});
      HapticFeedback.mediumImpact();
      setState(() => lastResult = {'result': 'valid', 'offlineProvisional': true,
        'booking': {'passengerName': 'Queued — needs sync'}});
    }
  }

  void _openScanner() {
    final ctl = MobileScannerController(torchEnabled: false);
    bool handled = false;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => StatefulBuilder(
      builder: (ctx, setS) => Scaffold(
        appBar: AppBar(
          title: const Text('Scan booking'),
          actions: [
            IconButton(icon: const Icon(Icons.flashlight_on),
              onPressed: () { ctl.toggleTorch(); }),
          ],
        ),
        body: MobileScanner(
          controller: ctl,
          onDetect: (cap) {
            if (handled) return;
            final raw = cap.barcodes.firstOrNull?.rawValue;
            if (raw == null) return;
            handled = true;
            Navigator.of(context).pop();
            try {
              final p = Map<String, dynamic>.from(jsonDecode(raw) as Map);
              _verify(bid: p['bid'], tid: p['tid'], nonce: p['nonce'], code: p['code']);
            } catch (_) {
              _verify(code: raw);
            }
          },
        ),
      ),
    )));
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      child: Scaffold(
        appBar: AppBar(title: const Text('PARK MODE'), backgroundColor: Colors.black),
        body: RefreshIndicator(
          onRefresh: () async { await _load(); await _syncQueue(); },
          child: Padding(padding: const EdgeInsets.all(16), child: ListView(children: [
            if (syncing) const Text('Syncing queued scans…', style: TextStyle(color: Color(0xFFFFC300))),
            if (lastSync != null) Text('Last sync ${lastSync!.hour}:${lastSync!.minute.toString().padLeft(2, '0')} · pull to refresh',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 6),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFC300),
                foregroundColor: Colors.black, minimumSize: const Size(200, 64),
                textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              onPressed: _openScanner, child: const Text('◉ SCAN BOOKING')),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: codeCtrl, style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Or enter trip code', labelStyle: TextStyle(color: Colors.grey)))),
              IconButton(icon: const Icon(Icons.check, color: Color(0xFFFFC300)),
                onPressed: () => _verify(code: codeCtrl.text.trim())),
            ]),
            const SizedBox(height: 12),
            if (lastResult != null) VerifyResult(
              result: lastResult!['result'] as String,
              subtitle: lastResult!['offlineProvisional'] == true
                  ? 'LIKELY VALID (offline) — Needs sync'
                  : ((lastResult!['booking'] as Map?)?.toString()),
            ),
            const SizedBox(height: 12),
            const Text("Today's trips — tap for queue", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            if (loading) const CircularProgressIndicator()
            else ...trips.map((e) {
              final t = Map<String, dynamic>.from(e as Map);
              final left = (t['capacity'] as int) - (t['booked_count'] as int);
              return Card(color: const Color(0xFF1F1F1F), child: ListTile(
                title: Text("${t['from_park']} → ${t['to_park']}",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                subtitle: Text('Booked ${t['booked_count']} · Arrived ${t['arrived_count']} · Left $left · ${t['status']}',
                  style: const TextStyle(color: Colors.grey)),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) =>
                  TripQueueScreen(tripId: t['id'].toString(), title: "${t['from_park']} → ${t['to_park']}"))),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) => api.markTripStatus(t['id'].toString(), v).then((_) => _load()),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'ready_to_leave', child: Text('Ready to Leave')),
                    PopupMenuItem(value: 'departed', child: Text('Departed')),
                    PopupMenuItem(value: 'completed', child: Text('Completed')),
                  ],
                ),
              ));
            }),
          ])),
        ),
      ),
    );
  }
}
