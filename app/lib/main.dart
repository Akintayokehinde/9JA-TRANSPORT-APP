import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/theme/app_theme.dart';
import 'core/firebase/firebase_init.dart';
import 'core/storage/hive_boxes.dart';
import 'core/network/functions_client.dart';
import 'features/auth/auth_screen.dart';
import 'features/search/search_screen.dart';
import 'features/booking/my_bookings_screen.dart';
import 'features/verify/park_mode_screen.dart';
import 'features/driver/driver_trips_screen.dart';
import 'features/payments/notifications_screen.dart';
import 'features/payments/daily_close_screen.dart';
import 'features/support/support_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initFirebase();
  await HiveBoxes.init();
  runApp(const NineJaApp());
}

class NineJaApp extends StatelessWidget {
  const NineJaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '9ja Transport',
      theme: AppTheme.light(),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (_, snap) => snap.data == null ? const AuthScreen() : const HomeShell(),
      ),
    );
  }
}

/// Bottom tabs: Book, Bookings, Park Mode, Driver, More.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int idx = 0;
  static const screens = [SearchScreen(), MyBookingsScreen(), ParkModeScreen(), DriverTripsScreen(), _MoreScreen()];

  @override
  void initState() {
    super.initState();
    // Phase 8: register FCM token for the 4 critical pushes.
    FirebaseMessaging.instance.getToken().then((t) {
      if (t != null) FunctionsClient().saveFcmToken(t).catchError((_) {});
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: idx, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: idx,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => idx = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Book'),
          BottomNavigationBarItem(icon: Icon(Icons.confirmation_number), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'Park'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_bus), label: 'Driver'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}

class _MoreScreen extends StatelessWidget {
  const _MoreScreen();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(children: [
        ListTile(title: const Text('Notifications'), onTap: () =>
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
        ListTile(title: const Text('Daily close (workers)'), onTap: () =>
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DailyCloseScreen()))),
        ListTile(title: const Text('Safety & Support'), onTap: () =>
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SupportScreen()))),
        ListTile(title: const Text('Sign out'), onTap: () => FirebaseAuth.instance.signOut()),
      ]),
    );
  }
}
