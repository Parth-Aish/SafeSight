import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LiveTrackingScreen extends StatefulWidget {
  final String pin;
  const LiveTrackingScreen({super.key, required this.pin});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late AnimationController _pulseController;
  bool _hasInitialLocked = false;

  @override
  void initState() {
    super.initState();
    // Pulse animation for the live dot
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("LIVE TRACKING",
                style: GoogleFonts.outfit(
                    color: const Color(0xFFF43F5E),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 2.0)),
            // FIX: Changed 'tracking' to 'letterSpacing'
            Text("PIN: ${widget.pin}",
                style: GoogleFonts.spaceGrotesk(
                    color: Colors.white, fontSize: 18, letterSpacing: 4.0)),
          ],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        // Listen to the specific PIN's live data stream
        stream: FirebaseFirestore.instance
            .collection('live_sessions')
            .doc(widget.pin)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(
                child: Text("Error: ${snapshot.error}",
                    style: const TextStyle(color: Colors.red)));
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF38BDF8)));

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.satellite_alt,
                      size: 80, color: Colors.white24),
                  const SizedBox(height: 16),
                  Text("Session Ended or Invalid PIN",
                      style: GoogleFonts.outfit(
                          color: Colors.white, fontSize: 20)),
                  Text("The user has stopped broadcasting.",
                      style: GoogleFonts.outfit(color: Colors.white54)),
                ],
              ),
            );
          }

          // Extract live coordinates & statuses
          final data = snapshot.data!.data() as Map<String, dynamic>;

          // NEW: Check for Arrival Status!
          final status = data['status'] ?? 'ACTIVE';
          final destName = data['destinationName'] ?? '';

          if (status == 'ARRIVED') {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: const Color(0xFF34D399).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified_user,
                        size: 120, color: Color(0xFF34D399)),
                  ),
                  const SizedBox(height: 32),
                  Text("SAFE ARRIVAL",
                      style: GoogleFonts.outfit(
                          color: const Color(0xFF34D399),
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2)),
                  const SizedBox(height: 12),
                  Text("User has securely reached $destName.",
                      style: GoogleFonts.outfit(
                          color: Colors.white70, fontSize: 18)),
                  const SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF34D399),
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text("RETURN TO DASHBOARD",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, letterSpacing: 1)),
                  )
                ],
              ),
            );
          }

          final double lat = data['lat'];
          final double lng = data['lng'];
          final LatLng targetPosition = LatLng(lat, lng);

          // Auto-center the camera on the very first GPS ping
          if (!_hasInitialLocked) {
            _hasInitialLocked = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _mapController.move(targetPosition, 16.5);
            });
          }

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: targetPosition,
                  initialZoom: 16.5,
                  maxZoom: 18.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.safesight',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: targetPosition,
                        width: 80,
                        height: 80,
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                // Radar Pulse Effect
                                Container(
                                  width: 40 + (40 * _pulseController.value),
                                  height: 40 + (40 * _pulseController.value),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFF43F5E).withValues(
                                        alpha:
                                            0.2 * (1 - _pulseController.value)),
                                  ),
                                ),
                                // Inner Core
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFF43F5E),
                                    border: Border.all(
                                        color: Colors.white, width: 3),
                                    boxShadow: const [
                                      BoxShadow(
                                          color: Colors.black45, blurRadius: 10)
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Re-center button
              Positioned(
                bottom: 40,
                right: 20,
                child: FloatingActionButton(
                  backgroundColor: const Color(0xFF0F172A),
                  onPressed: () => _mapController.move(targetPosition, 16.5),
                  child:
                      const Icon(Icons.my_location, color: Color(0xFF38BDF8)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
