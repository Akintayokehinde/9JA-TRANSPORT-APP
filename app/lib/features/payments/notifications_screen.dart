import 'package:flutter/material.dart';
import '../../core/network/functions_client.dart';

/// Phase 8: FCM inbox (server notifications table). Push arrives via FCM; this is history.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final api = FunctionsClient();
  List items = [];
  bool loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r = await api.myNotifications();
      setState(() { items = List.from(r['notifications'] ?? []); loading = false; });
    } catch (_) { setState(() => loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: items.isEmpty
          ? const Center(child: Text('No notifications yet. Critical pushes: booking, 1h reminder, cancelled, refund.'))
          : ListView.builder(itemCount: items.length, itemBuilder: (_, i) {
              final n = Map<String, dynamic>.from(items[i] as Map);
              return ListTile(title: Text('${n['title'] ?? ''}'), subtitle: Text('${n['body'] ?? ''}'));
            }),
    );
  }
}
