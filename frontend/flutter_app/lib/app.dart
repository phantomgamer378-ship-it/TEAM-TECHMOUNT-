import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/vr_theme.dart';
import 'core/theme/vr_colors.dart';
import 'core/constants/app_constants.dart';
import 'services/api_client.dart';

import 'features/onboarding/onboarding_screen.dart';
import 'features/home/home_screen.dart';
import 'features/live_call/live_call_screen.dart';
import 'features/scanner/scanner_screen.dart';
import 'features/call_history/call_history_screen.dart';
import 'features/reports/reports_screen.dart';
import 'features/profile/profile_screen.dart';

class VanirakshakApp extends StatefulWidget {
  const VanirakshakApp({super.key});

  @override
  State<VanirakshakApp> createState() => _VanirakshakAppState();
}

class _VanirakshakAppState extends State<VanirakshakApp> {
  bool _initialized = false;
  bool _needsOnboarding = true;
  late final ApiClient _api;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _needsOnboarding = !(prefs.getBool(AppConstants.prefOnboardingDone) ?? false);
    final baseUrl = await ApiClient.loadBaseUrl();
    _api = ApiClient(baseUrl);
    setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: AppConstants.appName,
      theme: VrTheme.dark(),
      home: _needsOnboarding
          ? OnboardingScreen(
              onComplete: () => setState(() => _needsOnboarding = false),
            )
          : _MainShell(api: _api),
    );
  }
}

class _MainShell extends StatefulWidget {
  const _MainShell({required this.api});
  final ApiClient api;

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _currentIndex = 0;
  late List<Widget> _views;

  @override
  void initState() {
    super.initState();
    _buildViews();
  }

  void _buildViews() {
    _views = [
      VrHomeScreen(api: widget.api, key: UniqueKey()),
      VrCallHistoryScreen(api: widget.api, key: UniqueKey()),
      VrScannerScreen(api: widget.api, key: UniqueKey()),
      const VrReportsScreen(),
      VrProfileScreen(api: widget.api, onUrlChanged: () => setState(_buildViews), key: UniqueKey()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _views,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: VrColors.surface,
        selectedItemColor: VrColors.primary,
        unselectedItemColor: VrColors.textMuted,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history_outlined), activeIcon: Icon(Icons.history), label: 'Calls'),
          BottomNavigationBarItem(icon: Icon(Icons.search_outlined), activeIcon: Icon(Icons.search), label: 'Scan'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), activeIcon: Icon(Icons.analytics), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'More'),
        ],
      ),
    );
  }
}
