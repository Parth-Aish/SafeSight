import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

// Import our new Core setup
import 'core/theme/app_theme.dart';

// Import the Feature Tabs
import 'features/dashboard/presentation/dashboard_tab.dart';
import 'features/profile/presentation/profile_tab.dart';

// REPLACED OLD IMPORT WITH NEW FEATURE FOLDER IMPORT
import 'features/map/presentation/map_screen.dart';

import 'features/emergency/presentation/screens/active_sos_screen.dart';
import 'features/emergency/presentation/controllers/sos_controller.dart';
import 'features/emergency/domain/models/emergency_state.dart';
import 'src/features/emergency/presentation/screens/walk_with_me_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  bool _isSosScreenOpen = false;

  // The 3 main tabs of our application
  static const List<Widget> _pages = [
    DashboardTab(),
    MapScreen(),
    ProfileTab(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sosControllerProvider, (previous, next) {
      final wasActive = previous?.phase == EmergencyPhase.triggered || previous?.phase == EmergencyPhase.broadcasting;
      final isActive = next.phase == EmergencyPhase.triggered || next.phase == EmergencyPhase.broadcasting;

      if (isActive && !_isSosScreenOpen) {
        _isSosScreenOpen = true;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ActiveSosScreen(),
            fullscreenDialog: true,
          ),
        ).then((_) {
          _isSosScreenOpen = false;
        });
      } else if (!isActive && _isSosScreenOpen) {
        Navigator.of(context).pop();
        _isSosScreenOpen = false;
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.slate900,
      extendBody: true,
      appBar: _selectedIndex == 1
          ? null
          : AppBar(
              backgroundColor: AppTheme.slate900,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: RichText(
                text: TextSpan(
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textWhite,
                  ),
                  children: const [
                    TextSpan(text: 'Safe'),
                    TextSpan(
                        text: 'Sight',
                        style: TextStyle(color: AppTheme.sky400)),
                  ],
                ),
              ),
              actions: [
                if (_selectedIndex == 2)
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined,
                        color: AppTheme.textWhite),
                    onPressed: () {},
                  ),
                const SizedBox(width: 8),
              ],
            ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.slate800.withValues(alpha: 0.7),
              border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            ),
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: AppTheme.sky400,
              unselectedItemColor: Colors.white38,
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              type: BottomNavigationBarType.fixed,
              showUnselectedLabels: true,
              selectedLabelStyle:
                  GoogleFonts.outfit(fontWeight: FontWeight.bold),
              unselectedLabelStyle: GoogleFonts.outfit(),
              items: const [
                BottomNavigationBarItem(
                    icon: Icon(Icons.shield_outlined),
                    activeIcon: Icon(Icons.shield),
                    label: 'Home'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.map_outlined),
                    activeIcon: Icon(Icons.map),
                    label: 'Nearby'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    activeIcon: Icon(Icons.person),
                    label: 'Profile'),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const WalkWithMeScreen(),
              fullscreenDialog: true,
            ),
          );
        },
        backgroundColor: AppTheme.sky400,
        icon: const Icon(Icons.touch_app, color: AppTheme.slate900),
        label: Text(
          'Walk With Me',
          style: GoogleFonts.outfit(
            color: AppTheme.slate900,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

