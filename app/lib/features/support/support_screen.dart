import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/network/functions_client.dart';

/// Phase 9: safety (share trip, emergency), complaints, ratings.
class SupportScreen extends StatefulWidget {
  final Map? trip;
  final String? bookingId;
  final String? tripId;
  const SupportScreen({super.key, this.trip, this.bookingId, this.tripId});
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final api = FunctionsClient();
  final complaint = TextEditingController();
  int stars = 5;

  Future<void> _complain(String category) async {
    try {
      await api.createComplaint(bookingId: widget.bookingId, category: category,
        message: complaint.text.trim().isEmpty ? category : complaint.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report sent')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _rate() async {
    if (widget.tripId == null || widget.bookingId == null) return;
    try {
      await api.createRating(tripId: widget.tripId!, bookingId: widget.bookingId!, score: stars);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks for rating')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trip ?? {};
    return Scaffold(
      appBar: AppBar(title: const Text('Safety & Support')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Emergency', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const Text('Call 112 (national) or Lagos 767. Then call support.'),
          const SizedBox(height: 8),
          Row(children: const [
            Chip(label: Text('112')), SizedBox(width: 8), Chip(label: Text('767 Lagos')),
          ]),
        ]))),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Share trip', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          SelectableText('I am on 9ja Transport ${t['from_park'] ?? ''}→${t['to_park'] ?? ''} '
            'driver ${t['driver_name'] ?? ''} ${t['plate_no'] ?? ''} booking ${widget.bookingId ?? ''}'),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text:
                'I am on 9ja Transport ${t['from_park'] ?? ''}→${t['to_park'] ?? ''} '
                'driver ${t['driver_name'] ?? ''} ${t['plate_no'] ?? ''} booking ${widget.bookingId ?? ''}'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Trip details copied — paste to WhatsApp/SMS')));
            },
            icon: const Icon(Icons.copy), label: const Text('Copy to share')),
        ]))),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Report a problem', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          TextField(controller: complaint, decoration: const InputDecoration(
            labelText: 'What happened?', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            'Driver did not show up', 'Vehicle was different', 'Wrong fare',
            'Booking not recognised', 'Payment problem', 'Safety concern',
          ].map((c) => ActionChip(label: Text(c), onPressed: () => _complain(c))).toList()),
        ]))),
        if (widget.tripId != null) Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Rate trip', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          Row(children: List.generate(5, (i) => IconButton(
            icon: Icon(i < stars ? Icons.star : Icons.star_border, color: const Color(0xFFFFC300)),
            onPressed: () => setState(() => stars = i + 1)))),
          ElevatedButton(onPressed: _rate, child: const Text('Submit rating')),
        ]))),
      ]),
    );
  }
}
