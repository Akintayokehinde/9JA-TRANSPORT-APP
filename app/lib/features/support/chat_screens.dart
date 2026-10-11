import 'package:flutter/material.dart';

/// DanfoBot: offline FAQ answers (mirrors landing FAQ + refund rules).
/// Live agent chat stays server-side for production; pilot uses a simulated queue.
class Faq {
  final List<String> keys;
  final String q, a;
  const Faq(this.keys, this.q, this.a);
}

const _faqs = [
  Faq(['internet', 'offline', 'network', 'data'], 'Do I need internet at the park?',
    'No. Your slip is saved on your phone and opens offline. The worker’s scanner confirms it.'),
  Faq(['pay online', 'must i pay', 'cash', 'reserve'], 'Must I pay online?',
    'No. Reserve your space and pay cash when you arrive. Online payment is optional.'),
  Faq(['miss', 'late', 'no-show', 'grace'], 'What if I miss the bus?',
    'There is a 15-minute grace period after departure. After that your space may be given to someone else.'),
  Faq(['driver', 'verify', 'safe', 'know my'], 'How do I know my driver?',
    'You see the driver’s photo, name, phone, vehicle and plate number before you board — only verified drivers operate.'),
  Faq(['fare change', 'price', 'increase'], 'What if the fare changes after I book?',
    'It can’t. Your fare is locked at the moment you book.'),
  Faq(['refund', 'cancel', 'money back'], 'How do refunds work?',
    'Cancel >6h before: full refund (minus small charge). 1–6h: half. Under 1h: no refund.'),
  Faq(['track', 'live', 'where is', 'bus'], 'Can I track my bus?',
    'Yes! Once the bus departs, open Live Tracking to see the danfo move with live ETA.'),
  Faq(['wallet', 'fund', 'top up', 'balance'], 'How does the wallet work?',
    'Top up from the payment options when booking. Wallet payments are instant, and cancels refund straight back.'),
];

String _answer(String text) {
  final t = text.toLowerCase();
  for (final f in _faqs) {
    if (f.keys.any(t.contains)) return f.a;
  }
  return 'I don’t have that answer yet — try Live Chat for an agent, or words like refund, fare, tracking, wallet.';
}

class _Msg {
  final bool me;
  final String text;
  final bool agent;
  _Msg(this.me, this.text, {this.agent = false});
}

class FaqBotScreen extends StatefulWidget {
  const FaqBotScreen({super.key});
  @override
  State<FaqBotScreen> createState() => _FaqBotScreenState();
}

class _FaqBotScreenState extends State<FaqBotScreen> {
  final input = TextEditingController();
  final msgs = <_Msg>[_Msg(false, 'Hello! I\'m DanfoBot 🚌 Ask me anything, or tap a question below.')];

  void _ask(String text) {
    if (text.trim().isEmpty) return;
    setState(() => msgs.add(_Msg(true, text.trim())));
    input.clear();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => msgs.add(_Msg(false, _answer(text))));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🤖 Bot Chat')),
      body: Column(children: [
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: msgs.length,
          itemBuilder: (_, i) => Align(
            alignment: msgs[i].me ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: msgs[i].me ? const Color(0xFF121212) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14)),
              child: Text(msgs[i].text,
                style: TextStyle(color: msgs[i].me ? const Color(0xFFFFC300) : Colors.black)),
            ),
          ),
        )),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: _faqs.map((f) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ActionChip(label: Text(f.q, style: const TextStyle(fontSize: 12)),
                onPressed: () => _ask(f.q)),
            )).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            Expanded(child: TextField(controller: input,
              decoration: const InputDecoration(hintText: 'Type your question…', border: OutlineInputBorder()),
              onSubmitted: _ask)),
            IconButton(icon: const Icon(Icons.send), onPressed: () => _ask(input.text)),
          ]),
        ),
      ]),
    );
  }
}

class LiveChatScreen extends StatefulWidget {
  const LiveChatScreen({super.key});
  @override
  State<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends State<LiveChatScreen> {
  final input = TextEditingController();
  final msgs = <_Msg>[_Msg(false, 'Support is online 8am–8pm. Say hello and an agent joins you here.', agent: true)];
  bool joined = false;
  String status = 'Demo: simulated agent queue (production: real-time agent chat).';

  void _send() {
    final v = input.text.trim();
    if (v.isEmpty) return;
    setState(() {
      msgs.add(_Msg(true, v));
      status = 'You are #2 in queue — an agent is joining…';
    });
    input.clear();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        if (!joined) {
          joined = true;
          msgs.add(_Msg(false, 'Hello, this is Adaeze from 9ja Support 👋 How can I help — booking, payment, or trip?', agent: true));
          status = 'Adaeze (support) is with you now. Avg reply ~2 min.';
        } else {
          msgs.add(_Msg(false, 'Noted — I’ve logged that on your account. Anything else I can do?', agent: true));
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('💬 Live Chat')),
      body: Column(children: [
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: msgs.length,
          itemBuilder: (_, i) => Align(
            alignment: msgs[i].me ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: msgs[i].me
                    ? const Color(0xFF121212)
                    : msgs[i].agent
                        ? const Color(0xFFE0EAFF)
                        : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14)),
              child: Text(msgs[i].text,
                style: TextStyle(color: msgs[i].me ? const Color(0xFFFFC300) : Colors.black)),
            ),
          ),
        )),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(status, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12))),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            Expanded(child: TextField(controller: input,
              decoration: const InputDecoration(hintText: 'Type a message…', border: OutlineInputBorder()),
              onSubmitted: (_) => _send())),
            IconButton(icon: const Icon(Icons.send), onPressed: _send),
          ]),
        ),
      ]),
    );
  }
}
