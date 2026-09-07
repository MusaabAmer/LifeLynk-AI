import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_screen.dart';
import '../../../search/presentation/screens/search_screen.dart';
import '../../../ai/presentation/screens/ai_screen.dart';
import '../../../sos/presentation/screens/sos_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';

import '../../providers/dashboard_provider.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../widgets/dashboard_bottom_nav.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _pages = [
      HomeScreen(
        onSearchBlood: _openSearch,
        onCreateSos: _openCreateSos,
        onProfileTap: _openProfile,
      ),
      const SearchScreen(),
      const SosScreen(),
      const AiScreen(),
      const ProfileScreen(),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDashboard();
    });
  }

  // ============================================================
  // INITIALIZE DASHBOARD
  // ============================================================

  Future<void> _initializeDashboard() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null || !mounted) {
      return;
    }

    // ------------------------------------------------------------
    // LOAD DASHBOARD DATA
    // ------------------------------------------------------------

    await context
        .read<DashboardProvider>()
        .loadDashboard(user.id);

    if (!mounted) {
      return;
    }

    // ------------------------------------------------------------
    // LOAD NOTIFICATIONS
    // ------------------------------------------------------------

    final notificationProvider =
        context.read<NotificationProvider>();

    await notificationProvider.loadNotifications();

    if (!mounted) {
      return;
    }

    // ------------------------------------------------------------
    // START SUPABASE REALTIME NOTIFICATIONS
    // ------------------------------------------------------------

    notificationProvider.startRealtimeListener();
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  void _onNavigationTap(int index) {
    if (index < 0 || index >= _pages.length) {
      return;
    }

    if (_currentIndex == index) {
      return;
    }

    setState(() {
      _currentIndex = index;
    });
  }

  // ============================================================
  // OPEN SEARCH
  // ============================================================

  void _openSearch() {
    _onNavigationTap(1);
  }

  // ============================================================
  // OPEN PROFILE
  // ============================================================

  void _openProfile() {
    _onNavigationTap(4);
  }

  // ============================================================
  // OPEN SOS
  // ============================================================

  void _openCreateSos() {
    _onNavigationTap(2);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),

      bottomNavigationBar: DashboardBottomNav(
        currentIndex: _currentIndex,
        onTap: _onNavigationTap,
      ),
    );
  }
}

