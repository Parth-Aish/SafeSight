import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/global_cache.dart';
import '../../../services/safety_service.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../sos/presentation/sos_screens.dart';
import '../../sos/presentation/fake_call_screen.dart';
import '../../sos/presentation/live_tracking_screen.dart';

import 'widgets/incident_report_sheet.dart';
import 'widgets/safe_zone_list.dart';
import 'widgets/sos_button.dart';
import 'widgets/broadcast_setup_sheet.dart';

class DashboardTab extends ConsumerStatefulWidget {
  const DashboardTab({super.key});

  @override
  ConsumerState<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends ConsumerState<DashboardTab>
    with SingleTickerProviderStateMixin {
  String _currentAddress = "Acquiring GPS Signal...";
  String _lastCity = "your immediate vicinity";
  List<dynamic> _dashboardZones = [];

  List<Map<String, String>> _emergencyContacts = [];

  bool _isAnalyzingSafety = true;
  double _safetyScore = 0.0;
  String _safetyStatus = "ANALYZING...";
  Color _safetyColor = const Color(0xFF38BDF8);
  String _safetyMessage = "Establishing secure connection...";

  int _newsCount = 0;
  int _infraCount = 0;
  int _crowdCount = 0;

  late AnimationController _radarController;
  Timer? _autoRefreshTimer;

  Position? _lastKnownPosition;

  bool _isBroadcasting = false;
  String _broadcastPin = "";
  StreamSubscription<Position>? _positionStream;
  Timer? _broadcastTimer;

  bool _isShuttingDown = false;

  @override
  void initState() {
    super.initState();
    _radarController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();

    final user = FirebaseAuth.instance.currentUser;
    if (user?.email != null) {
      SharedPreferences.getInstance()
          .then((prefs) => prefs.setString('user_email', user!.email!));
    }

    _fetchAddress(isSilent: false);
    _loadEmergencyContacts();
    _refreshZones();

    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      _refreshZones();
      _fetchAddress(isSilent: true);

      if (_isShuttingDown) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final activePin = prefs.getString('active_broadcast_pin');

      if (activePin != null && activePin.isNotEmpty && !_isBroadcasting) {
        if (mounted) {
          setState(() {
            _isBroadcasting = true;
            _broadcastPin = activePin;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _radarController.dispose();
    _autoRefreshTimer?.cancel();
    _positionStream?.cancel();
    _broadcastTimer?.cancel();
    super.dispose();
  }

  void _refreshZones() {
    setState(() {
      _dashboardZones = List.from(GlobalMapCache.cachedZones);
    });
  }

  void _manualRefresh() {
    HapticFeedback.lightImpact();
    _lastKnownPosition = null;
    _fetchAddress(isSilent: false);
    _refreshZones();
    _loadEmergencyContacts();
  }

  Future<void> _loadEmergencyContacts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists && doc.data()!.containsKey('emergency_contacts')) {
          final List contactsList = doc.data()!['emergency_contacts'];
          setState(() {
            _emergencyContacts =
                contactsList.map((c) => Map<String, String>.from(c)).toList();
          });

          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList('emergency_contacts',
              _emergencyContacts.map((c) => json.encode(c)).toList());
          return;
        } else {
          setState(() => _emergencyContacts = []);
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('emergency_contacts');
          return;
        }
      }
    } catch (e) {
      debugPrint("Firebase Contacts Error: $e");
    }

    final prefs = await SharedPreferences.getInstance();
    final List<String> contactsJson =
        prefs.getStringList('emergency_contacts') ?? [];
    setState(() {
      _emergencyContacts = contactsJson
          .map((c) => Map<String, String>.from(json.decode(c)))
          .toList();
    });
  }

  Future<void> _fetchAddress({required bool isSilent}) async {
    if (!isSilent && mounted) {
      setState(() {
        _currentAddress = "Refreshing GPS...";
        _isAnalyzingSafety = true;
        _safetyStatus = "RE-SCANNING...";
        _safetyMessage = "Fetching latest environment data...";
        _safetyColor = const Color(0xFF38BDF8);
      });
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted && !isSilent) {
          setState(() {
            _currentAddress = "Location Services Disabled";
            _safetyStatus = "OFFLINE";
            _safetyMessage = "Turn on GPS to enable area scanning.";
            _isAnalyzingSafety = false;
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (!isSilent) permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted && !isSilent)
            setState(() {
              _isAnalyzingSafety = false;
            });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted && !isSilent)
          setState(() {
            _isAnalyzingSafety = false;
          });
        return;
      }

      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 4),
        );
      } catch (e) {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      }

      if (isSilent && _lastKnownPosition != null) {
        double distanceMoved = Geolocator.distanceBetween(
          _lastKnownPosition!.latitude,
          _lastKnownPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        if (distanceMoved < 100) {
          _analyzeSafetyStatus(_lastKnownPosition!, _lastCity, isSilent: true);
          return;
        }
      }

      _lastKnownPosition = position;
      GlobalMapCache.userLocation =
          LatLng(position.latitude, position.longitude);

      String displayAddress =
          "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
      String cityForAnalysis = "your immediate vicinity";

      try {
        final url = Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=14&addressdetails=1');
        final response = await http.get(url, headers: {
          'User-Agent': 'SafeSightApp/1.0'
        }).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final address = data['address'];

          if (address != null) {
            final area = address['suburb'] ??
                address['neighbourhood'] ??
                address['road'] ??
                '';
            final city = address['city'] ??
                address['town'] ??
                address['county'] ??
                address['state'] ??
                '';

            String formattedAddress = [area, city]
                .where((e) => e.toString().trim().isNotEmpty)
                .join(', ');

            if (formattedAddress.isNotEmpty) {
              displayAddress = formattedAddress;
              cityForAnalysis = city;
              _lastCity = city;
            }
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _currentAddress = displayAddress;
        });

        _analyzeSafetyStatus(position, cityForAnalysis, isSilent: isSilent);
      }
    } catch (e) {
      debugPrint("Background Fetch Failed: $e");
    }
  }

  Future<void> _analyzeSafetyStatus(Position pos, String city,
      {required bool isSilent}) async {
    if (!mounted) return;

    if (!isSilent) {
      setState(() {
        _isAnalyzingSafety = true;
        _safetyStatus = "SCANNING AREA...";
        _safetyMessage = "Triangulating data for $city...";
      });
    }

    final safetyService = ref.read(safetyServiceProvider);
    final report = await safetyService.analyzeLocation(pos: pos, city: city);

    if (!mounted) return;

    setState(() {
      _safetyScore = report.score;
      _safetyStatus = report.status;
      _safetyMessage = report.message;
      _safetyColor = report.color;
      _newsCount = report.newsCount;
      _infraCount = report.infraCount;
      _crowdCount = report.crowdCount;
      _isAnalyzingSafety = false;
      _refreshZones();
    });
  }

  void _showNoContactsAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFEAB308)),
            const SizedBox(width: 8),
            Text("Action Required",
                style: GoogleFonts.outfit(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
            "Connect at least one Guardian in your Profile before using SOS.",
            style: GoogleFonts.outfit(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Color(0xFF38BDF8))),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleLiveTracking() async {
    // If already broadcasting, this button acts as STOP
    if (_isBroadcasting) {
      await _stopBroadcasting(reason: "Manually Stopped");
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> contactsJson =
          prefs.getStringList('emergency_contacts') ?? [];
      final List<String> guardians =
          prefs.getStringList('guardian_emails') ?? [];

      if (contactsJson.isEmpty && guardians.isEmpty) {
        if (mounted) _showNoContactsAlert();
        return;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Location Services disabled. Turn on GPS.")));
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Location Permission denied.")));
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Location Permission permanently denied.")));
        return;
      }

      if (!mounted) return;

      final dynamic config = await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => const BroadcastSetupSheet(),
      );

      if (config == null || config is! Map) {
        debugPrint("Broadcast Setup Cancelled.");
        return;
      }

      final int durationMinutes = config['duration'] ?? 30;
      final LatLng? dest = config['destination'];
      final String destName = config['destName'] ?? "";

      if (dest != null) {
        Position currentPos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        final double initialDist = const Distance().as(LengthUnit.Meter,
            LatLng(currentPos.latitude, currentPos.longitude), dest);

        if (initialDist < 50) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  "You are already at $destName! Broadcast cancelled.",
                  style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
              backgroundColor: const Color(0xFFEAB308),
            ));
          }
          return;
        }
      }

      final pin = (100000 + Random().nextInt(900000)).toString();

      _isShuttingDown = false;
      await prefs.setString('active_broadcast_pin', pin);

      if (mounted) {
        setState(() {
          _isBroadcasting = true;
          _broadcastPin = pin;
        });
      }

      if (durationMinutes > 0) {
        _broadcastTimer = Timer(Duration(minutes: durationMinutes), () {
          _stopBroadcasting(reason: "Time Expired");
        });
      }

      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high, distanceFilter: 5),
      ).listen((Position pos) async {
        if (dest != null) {
          final dist = const Distance()
              .as(LengthUnit.Meter, LatLng(pos.latitude, pos.longitude), dest);
          if (dist < 50) {
            _handleArrival(destName, pin);
            return;
          }
        }

        try {
          await FirebaseFirestore.instance
              .collection('live_sessions')
              .doc(pin)
              .set({
            'lat': pos.latitude,
            'lng': pos.longitude,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'ACTIVE',
            'destinationName': destName,
            'victimUid': FirebaseAuth.instance.currentUser?.uid,
          });
        } catch (e) {
          debugPrint("Failed to push location to Firebase: $e");
        }
      }, onError: (e) {
        debugPrint("Live tracking error: $e");
      });

      // Guardian dispatch is handled by the in-app emergency repository.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Failed to start: $e"),
            backgroundColor: Colors.redAccent));
      }
    } finally {
      // FIX: Ensure state is clean even if errors occur
      if (mounted && !_isBroadcasting) {
        setState(() {
          _isShuttingDown = false;
        });
      }
    }
  }

  // FORCEFUL OFFLINE-RESILIENT STOP LOGIC
  Future<void> _stopBroadcasting({String? reason}) async {
    debugPrint("🛑 FORCE STOPPING BROADCAST...");

    // 1. Lock the state immediately so timer doesn't interfere
    _isShuttingDown = true;

    // 2. Kill local streams
    await _positionStream?.cancel();
    _broadcastTimer?.cancel();
    _positionStream = null;

    // 3. Wipe Local Memory completely (Synchronous action, happens instantly)
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_broadcast_pin');
    await prefs.setBool('broadcast_cooldown', true);
    await prefs.reload(); // Force sync

    // 4. Update UI instantly for responsiveness, BEFORE waiting on Firebase
    if (mounted) {
      setState(() {
        _isBroadcasting = false;
      });
      if (reason != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Broadcast stopped: $reason",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.black)),
            backgroundColor: const Color(0xFF34D399)));
      }
    }

    // 5. Delete from Firebase (Wrapped in aggressive try-catch with timeout)
    if (_broadcastPin.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('live_sessions')
            .doc(_broadcastPin)
            .delete()
            .timeout(const Duration(
                seconds: 3)); // Don't hang forever if network is dead

        final alerts = await FirebaseFirestore.instance
            .collection('active_alerts')
            .where('pin', isEqualTo: _broadcastPin)
            .get()
            .timeout(const Duration(seconds: 3));

        for (var doc in alerts.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint(
            "Firebase cleanup failed/timed out during stop (Offline mode?): $e");
        // It's okay if this fails. The local UI state is already reset!
      }
    }

    _broadcastPin = "";

    // 6. Release the lock after a safe delay
    Future.delayed(const Duration(seconds: 30), () {
      prefs.setBool('broadcast_cooldown', false);
      _isShuttingDown = false;
    });
  }

  Future<void> _handleArrival(String destName, String pin) async {
    _isShuttingDown = true;
    await _positionStream?.cancel();
    _broadcastTimer?.cancel();

    try {
      await FirebaseFirestore.instance
          .collection('live_sessions')
          .doc(pin)
          .set({
        'status': 'ARRIVED',
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Failed to update arrival status: $e");
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_broadcast_pin');
    await prefs.reload();

    if (!mounted) return;

    setState(() {
      _isBroadcasting = false;
      _broadcastPin = "";
    });

    if (!context.mounted) return;

    showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF34D399)),
                  const SizedBox(width: 8),
                  Text("Arrived Safely",
                      style: GoogleFonts.outfit(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Text(
                  "You have reached $destName. Contacts have been notified and tracking has stopped.",
                  style: GoogleFonts.outfit(color: Colors.white70)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text("OK",
                        style: TextStyle(color: Color(0xFF38BDF8)))),
              ],
            )).then((_) => _isShuttingDown = false);
  }

  void _showTrackPinDialog() {
    final pinController = TextEditingController();
    showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
                backgroundColor: const Color(0xFF1E293B),
                title: Text("Track Emergency",
                    style: GoogleFonts.outfit(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                content: TextField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: GoogleFonts.spaceGrotesk(
                      color: Colors.white, fontSize: 24, letterSpacing: 8),
                  decoration: const InputDecoration(
                      hintText: "000000",
                      hintStyle: TextStyle(color: Colors.white24)),
                  textAlign: TextAlign.center,
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text("Cancel",
                          style: TextStyle(color: Colors.white54))),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38BDF8),
                        foregroundColor: const Color(0xFF0F172A)),
                    onPressed: () {
                      if (pinController.text.length == 6) {
                        Navigator.pop(dialogContext);
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => LiveTrackingScreen(
                                    pin: pinController.text)));
                      }
                    },
                    child: const Text("CONNECT",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                ]));
  }

  void _handleFakeCall() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> contactsJson =
        prefs.getStringList('emergency_contacts') ?? [];

    if (contactsJson.isEmpty) {
      if (mounted) _showNoContactsAlert();
      return;
    }

    final contact = Map<String, String>.from(json.decode(contactsJson[0]));
    String callerName = contact['name']!;
    String callerNumber = contact['phone']!;

    if (mounted) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  FakeCallScreen(name: callerName, number: callerNumber)));
    }
  }

  void _handleRecord() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isDismissible: false,
      enableDrag: false,
      builder: (context) => const AudioRecordingSheet(),
    );
  }

  void _handleSiren() {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => const SirenScreen()));
  }

  void _handleReportIncident() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const IncidentReportSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isBroadcasting)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFBE123C).withValues(alpha: 0.15),
                border: Border.all(color: const Color(0xFFF43F5E), width: 2),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFFF43F5E).withValues(alpha: 0.2),
                      blurRadius: 15)
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.satellite_alt,
                      color: Color(0xFFF43F5E), size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("LIVE BROADCASTING",
                            style: GoogleFonts.outfit(
                                color: const Color(0xFFF43F5E),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1)),
                        Text("PIN: $_broadcastPin",
                            style: GoogleFonts.spaceGrotesk(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.stop_circle,
                        color: Colors.white, size: 36),
                    onPressed: () =>
                        _stopBroadcasting(reason: "Manually Stopped"),
                    tooltip: "Stop Broadcasting",
                  )
                ],
              ),
            ),
          Row(
            children: [
              AnimatedBuilder(
                animation: _radarController,
                builder: (context, child) {
                  return Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF38BDF8).withValues(
                          alpha: 0.2 * (1 - _radarController.value)),
                    ),
                    child: const Icon(Icons.my_location,
                        color: Color(0xFF38BDF8), size: 16),
                  );
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _currentAddress,
                  style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh,
                    color: Color(0xFF38BDF8), size: 22),
                onPressed: _manualRefresh,
                tooltip: 'Refresh Status',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutExpo,
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: _isAnalyzingSafety
                      ? const Color(0xFF38BDF8).withValues(alpha: 0.5)
                      : _safetyColor.withValues(alpha: 0.5),
                  width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: _isAnalyzingSafety
                        ? const Color(0xFF38BDF8).withValues(alpha: 0.1)
                        : _safetyColor.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text("Environment Scan",
                          style: GoogleFonts.outfit(
                              color: Colors.white54,
                              fontSize: 13,
                              letterSpacing: 1.2),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: _safetyColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (_isAnalyzingSafety)
                            SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: _safetyColor))
                          else
                            Icon(
                                _safetyScore >= 0.75
                                    ? Icons.shield
                                    : (_safetyScore >= 0.5
                                        ? Icons.warning_amber
                                        : Icons.gpp_bad),
                                color: _safetyColor,
                                size: 14),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(_safetyStatus,
                                style: GoogleFonts.outfit(
                                    color: _safetyColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 0.5),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                      value: _isAnalyzingSafety ? null : _safetyScore,
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      valueColor: AlwaysStoppedAnimation<Color>(_safetyColor),
                      minHeight: 8),
                ),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(_safetyMessage,
                      key: ValueKey<String>(_safetyMessage),
                      style: GoogleFonts.outfit(
                          color: Colors.white, fontSize: 15, height: 1.4)),
                ),
                if (!_isAnalyzingSafety) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Divider(color: Colors.white10, height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _DiagnosticBadge(
                          icon: Icons.newspaper,
                          label: "News",
                          isGood: _newsCount <= 2),
                      _DiagnosticBadge(
                          icon: Icons.groups,
                          label: "Crowd",
                          isGood: _crowdCount == 0),
                    ],
                  )
                ]
              ],
            ),
          ),
          if (_assessment != null && _assessment!.verifiedSources.isNotEmpty) ...[
            const SizedBox(height: 16),
            _NewsSourcesList(sources: _assessment!.verifiedSources),
          ],
          const SizedBox(height: 40),
          Center(
              child: SOSButton(
            onNoContacts: _showNoContactsAlert,
          )),
          const SizedBox(height: 32),
          const Center(
              child: Text("Hold for 2 seconds to alert your paired guardian",
                  style: TextStyle(color: Colors.white38, fontSize: 12))),
          const SizedBox(height: 32),
          const SectionHeader(title: "Quick Actions"),
          const SizedBox(height: 16),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                      child: QuickActionCard(
                          icon: Icons.cell_tower,
                          label: "Broadcast",
                          color: const Color(0xFF34D399),
                          onTap: _toggleLiveTracking)),
                  Flexible(
                      child: QuickActionCard(
                          icon: Icons.radar,
                          label: "Track PIN",
                          color: const Color(0xFF38BDF8),
                          onTap: _showTrackPinDialog)),
                  Flexible(
                      child: QuickActionCard(
                          icon: Icons.call,
                          label: "Fake Call",
                          color: const Color(0xFFA855F7),
                          onTap: _handleFakeCall)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                      child: QuickActionCard(
                          icon: Icons.mic,
                          label: "Record",
                          color: const Color(0xFFF43F5E),
                          onTap: _handleRecord)),
                  Flexible(
                      child: QuickActionCard(
                          icon: Icons.campaign,
                          label: "Siren",
                          color: const Color(0xFFEAB308),
                          onTap: _handleSiren)),
                  Flexible(
                      child: QuickActionCard(
                          icon: Icons.report_problem,
                          label: "Report",
                          color: const Color(0xFFF43F5E),
                          onTap: _handleReportIncident)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionHeader(title: "Nearby Safe Zones"),
              TextButton(
                  onPressed: _manualRefresh,
                  child: const Text("Refresh",
                      style: TextStyle(color: Color(0xFF38BDF8)))),
            ],
          ),
          const SizedBox(height: 8),
          DynamicSafeZoneList(zones: _dashboardZones),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _DiagnosticBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isGood;

  const _DiagnosticBadge(
      {required this.icon, required this.label, required this.isGood});

  @override
  Widget build(BuildContext context) {
    final color = isGood ? const Color(0xFF34D399) : const Color(0xFFF43F5E);
    return Row(
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.8)),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

class _NewsSourcesList extends StatefulWidget {
  final List<dynamic> sources;

  const _NewsSourcesList({required this.sources});

  @override
  State<_NewsSourcesList> createState() => _NewsSourcesListState();
}

class _NewsSourcesListState extends State<_NewsSourcesList> {
  bool _expanded = false;

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () => setState(() => _expanded = !_expanded),
            leading: const Icon(Icons.article_outlined, color: Color(0xFF38BDF8)),
            title: Text(
              "Recent 7-Day Local Reports",
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: Icon(
              _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Colors.white54,
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                children: widget.sources.map((source) {
                  return InkWell(
                    onTap: () => _launchUrl(source.url),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.link, color: Colors.white38, size: 16),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  source.headline,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${source.publisher} • ${source.publishedDate}",
                                  style: GoogleFonts.outfit(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
