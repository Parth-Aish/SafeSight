import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../../../services/auth_service.dart';
import '../../../services/safety_service.dart';
import '../../../shared/widgets/shared_widgets.dart';

// Modular screen imports
import 'screens/emergency_contacts_screen.dart';
import 'screens/guardian_network_screen.dart';
import 'screens/saved_places_screen.dart';
import 'screens/incident_forum_screen.dart';

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  bool _backgroundAlertsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _backgroundAlertsEnabled = prefs.getBool('background_alerts') ?? false;
      });
    }
  }

  Future<void> _toggleBackgroundAlerts(bool value) async {
    if (value) {
      // Background monitoring requires specific permissions
      PermissionStatus notifStatus = await Permission.notification.request();
      PermissionStatus locStatus = await Permission.locationAlways.request();

      if (!notifStatus.isGranted || !locStatus.isGranted) {
        if (mounted) {
          showDialog(
              context: context,
              builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF1E293B),
                    title: const Text("Permissions Required",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    content: const Text(
                        "SafeSight requires 'Allow all the time' location access and Notification permissions to monitor your safety in the background.",
                        style: TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel")),
                      TextButton(
                          onPressed: () {
                            openAppSettings();
                            Navigator.pop(context);
                          },
                          child: const Text("Open Settings",
                              style: TextStyle(color: Color(0xFF38BDF8)))),
                    ],
                  ));
        }
        return;
      }
      final service = FlutterBackgroundService();
      await service.startService();
    } else {
      final service = FlutterBackgroundService();
      service.invoke("stopService");
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('background_alerts', value);
    if (mounted) setState(() => _backgroundAlertsEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authServiceProvider).currentUser;

    return SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(title: "My Profile"),
          const SizedBox(height: 24),
          Center(
              child: Column(children: [
            CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                child: Text(user?.email?[0].toUpperCase() ?? "U",
                    style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF38BDF8)))),
            const SizedBox(height: 16),
            Text(user?.email ?? "Anonymous User",
                style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            Text("Account Verified",
                style: GoogleFonts.outfit(
                    color: const Color(0xFF34D399), fontSize: 14)),
          ])),
          const SizedBox(height: 48),
          _buildBackgroundToggle(),
          SettingsTile(
              icon: Icons.contact_phone,
              title: "Emergency Contacts (SMS)",
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const EmergencyContactsScreen()))),
          SettingsTile(
              icon: Icons.hub,
              title: "App-to-App Guardians",
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const GuardianNetworkScreen()))),
          SettingsTile(
              icon: Icons.place,
              title: "Saved Places",
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SavedPlacesScreen()))),
          SettingsTile(
              icon: Icons.forum_outlined,
              title: "Community Incident Forum",
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const IncidentForumScreen()))),
          const SizedBox(height: 32),
          _buildActionButtons(context),
          const SizedBox(height: 100),
        ]));
  }

  Widget _buildBackgroundToggle() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _backgroundAlertsEnabled
            ? const Color(0xFF38BDF8).withValues(alpha: 0.1)
            : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: _backgroundAlertsEnabled
                ? const Color(0xFF38BDF8).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_active,
              color: _backgroundAlertsEnabled
                  ? const Color(0xFF38BDF8)
                  : Colors.white70),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Background Alerts",
                    style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                Text("Get notified of nearby threats",
                    style: GoogleFonts.outfit(
                        color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: _backgroundAlertsEnabled,
            onChanged: _toggleBackgroundAlerts,
            activeTrackColor: const Color(0xFF38BDF8),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(children: [
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            final pos = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high);
            await ref
                .read(safetyServiceProvider)
                .reportIncident(pos, type: "Quick Alert");
            if (context.mounted)
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Quick Alert Reported"),
                  backgroundColor: Colors.green));
          },
          icon: const Icon(Icons.warning_amber_rounded),
          label: const Text("QUICK REPORT ACTIVITY"),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBE123C).withValues(alpha: 0.15),
              foregroundColor: const Color(0xFFF43F5E),
              side: BorderSide(
                  color: const Color(0xFFF43F5E).withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 16)),
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
              onPressed: () async {
                await ref.read(authServiceProvider).signOut();
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout),
              label: const Text("LOGOUT"),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: const Color(0xFFF43F5E),
                  side: BorderSide(
                      color: const Color(0xFFF43F5E).withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 16)))),
    ]);
  }
}
