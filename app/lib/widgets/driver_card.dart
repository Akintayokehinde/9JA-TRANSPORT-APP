import 'package:flutter/material.dart';

/// Driver identity card — always visible before boarding (PRD §11, §19).
class DriverCard extends StatelessWidget {
  final String? name;
  final String? phone;
  final String? vehicleType;
  final String? plateNo;
  final bool verified;
  final double? rating;
  final int? trips;
  const DriverCard({super.key, this.name, this.phone, this.vehicleType, this.plateNo,
    this.verified = false, this.rating, this.trips});

  @override
  Widget build(BuildContext context) {
    final initial = (name ?? '?').isNotEmpty ? (name![0].toUpperCase()) : '?';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          CircleAvatar(radius: 28, backgroundColor: Colors.black,
            child: Text(initial, style: const TextStyle(color: Color(0xFFFFC300), fontWeight: FontWeight.w800, fontSize: 20))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(name ?? 'Driver TBD', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              if (verified) ...[const SizedBox(width: 6),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF0A7A3B), borderRadius: BorderRadius.circular(999)),
                  child: const Text('✓ VERIFIED', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)))],
            ]),
            const SizedBox(height: 2),
            Text('${vehicleType ?? 'danfo'} · ${plateNo ?? '—'} · ${phone ?? '—'}',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
            if (rating != null) Text('★${rating!.toStringAsFixed(1)} (${trips ?? 0} trips)',
              style: const TextStyle(fontSize: 13)),
          ])),
        ]),
      ),
    );
  }
}
