import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'services/auth_service.dart';
import 'dart:ui'; // Required for Glass Effect
import 'map_screen.dart'; // Import the Map Screen

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = [
    _DashboardTab(),
    MapScreen(), 
    _SettingsTab(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final slate900 = const Color(0xFF020617);
    final slate800 = const Color(0xFF0F172A);
    final sky400 = const Color(0xFF38BDF8);

    return Scaffold(
      backgroundColor: slate900,
      extendBody: true, // Key Step: Allows content to flow behind the glass bar
      
      // FIX 3: Dynamic AppBar. 
      // Null on MapScreen (index 1) for full screen.
      // Notification bell ONLY on Profile (index 2).
      appBar: _selectedIndex == 1 
          ? null 
          : AppBar(
              backgroundColor: slate900,
              elevation: 0,
              automaticallyImplyLeading: false, 
              title: RichText(
                text: TextSpan(
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  children: [
                    const TextSpan(text: 'Safe'),
                    TextSpan(text: 'Sight', style: TextStyle(color: sky400)),
                  ],
                ),
              ),
              actions: [
                // Notification Bell restricted to Profile Screen
                if (_selectedIndex == 2)
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                    onPressed: () {},
                  ),
                const SizedBox(width: 8),
              ],
            ),
            
      // FIX 1: IndexedStack PRESERVES STATE across tab switches. 
      // The map will never reload or lose directions when switching tabs!
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0), // Apple Blur
          child: Container(
            decoration: BoxDecoration(
              color: slate800.withValues(alpha: 0.7), 
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))), 
            ),
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent, 
              elevation: 0, 
              selectedItemColor: sky400,
              unselectedItemColor: Colors.white38,
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              type: BottomNavigationBarType.fixed,
              showUnselectedLabels: true,
              selectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              unselectedLabelStyle: GoogleFonts.outfit(),
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.shield_outlined), activeIcon: Icon(Icons.shield), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.map_outlined), activeIcon: Icon(Icons.map), label: 'Nearby'),
                BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 1. DASHBOARD TAB
// -----------------------------------------------------------------------------
class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  String _currentAddress = "Locating...";

  @override
  void initState() {
    super.initState();
    _fetchAddress();
  }

  Future<void> _fetchAddress() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _currentAddress = "Location Disabled");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _currentAddress = "Permission Denied");
        return;
      }

      // 1. Get Location
      Position? position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );

      // 2. Reverse Geocode via OpenStreetMap (Free, No API Key needed)
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=14&addressdetails=1');
      
      final response = await http.get(url, headers: {'User-Agent': 'SafeSightApp/1.0'}).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];
        
        if (address != null) {
          // Extract the best fitting local area and city
          final area = address['suburb'] ?? address['neighbourhood'] ?? address['road'] ?? '';
          final city = address['city'] ?? address['town'] ?? address['county'] ?? address['state'] ?? 'Unknown City';
          
          String formattedAddress = [area, city].where((e) => e.toString().trim().isNotEmpty).join(', ');
          if (formattedAddress.isEmpty) formattedAddress = "Current Location";

          if (mounted) setState(() => _currentAddress = formattedAddress);
        } else {
          if (mounted) setState(() => _currentAddress = "Location Found");
        }
      } else {
         if (mounted) setState(() => _currentAddress = "Location Found");
      }
    } catch (e) {
      debugPrint("Reverse Geocoding Error: $e");
      if (mounted) setState(() => _currentAddress = "Unknown Location");
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.white54, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _currentAddress,
                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1E293B),
                  const Color(0xFF0F172A),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Safety Status", style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF34D399).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Color(0xFF34D399), size: 14),
                          const SizedBox(width: 6),
                          Text("SAFE ZONE", style: GoogleFonts.outfit(color: const Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: 0.88,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
                    minHeight: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "You are in a well-monitored area with frequent patrols.",
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          Center(child: const _SOSButton()),
          const SizedBox(height: 32),

          const _SectionHeader(title: "Quick Actions"),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _QuickActionCard(icon: Icons.share_location, label: "Share Loc", color: Color(0xFF38BDF8)),
              _QuickActionCard(icon: Icons.record_voice_over, label: "Fake Call", color: Color(0xFFA855F7)),
              _QuickActionCard(icon: Icons.mic, label: "Record", color: Color(0xFFF43F5E)),
              _QuickActionCard(icon: Icons.campaign, label: "Whistle", color: Color(0xFFEAB308)),
            ],
          ),

          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionHeader(title: "Nearby Safe Zones"),
              TextButton(onPressed: () {}, child: Text("View All", style: TextStyle(color: Color(0xFF38BDF8)))),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: ListView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              children: const [
                _SafeZoneCard(name: "A2Z Cafe", type: "Verified Partner", distance: "200m", icon: Icons.coffee, rating: "4.9"),
                _SafeZoneCard(name: "City Mall", type: "Public Space", distance: "1.2km", icon: Icons.storefront, rating: "4.5"),
                _SafeZoneCard(name: "Metro Station", type: "Transport", distance: "500m", icon: Icons.train, rating: "4.8"),
              ],
            ),
          ),
          
          const SizedBox(height: 100), 
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 2. SETTINGS TAB 
// -----------------------------------------------------------------------------
class _SettingsTab extends ConsumerWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: "My Profile"),
          const SizedBox(height: 24),
          
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                  child: Text(
                    user?.email?[0].toUpperCase() ?? "U",
                    style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(user?.email ?? "User", style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                Text("Account Verified", style: GoogleFonts.outfit(color: const Color(0xFF34D399), fontSize: 14)),
              ],
            ),
          ),

          const SizedBox(height: 48),
          
          _SettingsTile(icon: Icons.security, title: "Security Settings"),
          _SettingsTile(icon: Icons.contact_phone, title: "Emergency Contacts"),
          _SettingsTile(icon: Icons.history, title: "Alert History"),
          
          const Spacer(),
          
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
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                side: BorderSide(color: const Color(0xFFF43F5E).withValues(alpha: 0.3)),
              ),
            ),
          ),
          const SizedBox(height: 100), 
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// HELPER WIDGETS
// -----------------------------------------------------------------------------

class _SOSButton extends StatefulWidget {
  const _SOSButton();
  @override
  State<_SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<_SOSButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF43F5E).withValues(alpha: 0.1),
            boxShadow: [BoxShadow(color: const Color(0xFFF43F5E).withValues(alpha: 0.2 * _controller.value), blurRadius: 30 * _controller.value, spreadRadius: 10 * _controller.value)],
          ),
          child: Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [Color(0xFFF43F5E), Color(0xFFBE123C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.touch_app, color: Colors.white, size: 32),
                  Text("SOS", style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white));
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _QuickActionCard({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

class _SafeZoneCard extends StatelessWidget {
  final String name;
  final String type;
  final String distance;
  final IconData icon;
  final String rating;
  const _SafeZoneCard({required this.name, required this.type, required this.distance, required this.icon, required this.rating});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: const Color(0xFF38BDF8), size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFEAB308), size: 12),
                    const SizedBox(width: 4),
                    Text(rating, style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(name, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(type, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12)),
              const SizedBox(width: 8),
              Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(distance, style: GoogleFonts.outfit(color: const Color(0xFF34D399), fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SettingsTile({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70),
          const SizedBox(width: 16),
          Text(title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 16)),
          const Spacer(),
          const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
        ],
      ),
    );
  }
}