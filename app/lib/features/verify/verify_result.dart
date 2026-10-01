import 'package:flutter/material.dart';

/// Full-screen verification result (Phase 6). Color + vibration cue for noisy parks.
class VerifyResult extends StatelessWidget {
  final String result; // valid|used|cancelled|expired
  final String? subtitle;
  const VerifyResult({super.key, required this.result, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final conf = {
      'valid': [const Color(0xFF0A7A3B), '✓ VALID BOOKING'],
      'used': [const Color(0xFF6B7280), 'ALREADY USED'],
      'cancelled': [const Color(0xFFD92D20), '✕ CANCELLED'],
      'expired': [const Color(0xFFF79009), '◷ EXPIRED'],
    }[result]!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: conf[0] as Color, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Text(conf[1] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22)),
        if (subtitle != null) ...[const SizedBox(height: 6),
          Text(subtitle!, style: const TextStyle(color: Colors.white, fontSize: 14), textAlign: TextAlign.center)],
      ]),
    );
  }
}
