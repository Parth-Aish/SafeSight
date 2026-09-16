import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../../shared/widgets/location_picker_screen.dart'; // NEW IMPORT

class BroadcastSetupSheet extends StatefulWidget {
  const BroadcastSetupSheet({super.key});

  @override
  State<BroadcastSetupSheet> createState() => _BroadcastSetupSheetState();
}

class _BroadcastSetupSheetState extends State<BroadcastSetupSheet> {
  int _selectedDurationIndex = 1; // Default: 30 mins
  int _selectedDestinationIndex = 0; // Default: None

  final List<int> _durations = [15, 30, 60, 0]; // 0 = Indefinite
  final List<String> _durationLabels = ["15m", "30m", "1h", "Until Stopped"];

  final List<String> _destinations = ["None", "Home", "Office"];
  final List<IconData> _destIcons = [
    Icons.not_listed_location,
    Icons.home,
    Icons.work
  ];

  bool _isLoadingLoc = false;

  Future<LatLng?> _getOrSetLocation(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('${key}_lat');
    final lng = prefs.getDouble('${key}_lng');

    // If we already saved it before, just use it!
    if (lat != null && lng != null) {
      return LatLng(lat, lng);
    }

    // If not set, ask HOW they want to set it
    if (!mounted) return null;
    int? choice = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: Text("Set $key Location",
                  style: const TextStyle(color: Colors.white)),
              content: Text(
                  "You haven't set your $key yet. How would you like to set it?",
                  style: const TextStyle(color: Colors.white70)),
              actionsAlignment: MainAxisAlignment.spaceEvenly,
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, 1),
                    child: const Text("Current GPS",
                        style: TextStyle(color: Color(0xFF38BDF8)))),
                ElevatedButton(
                    onPressed: () => Navigator.pop(context, 2),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38BDF8),
                        foregroundColor: const Color(0xFF0F172A)),
                    child: const Text("Choose on Map",
                        style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ));

    if (choice == null) return null; // Cancelled

    LatLng? finalPosition;

    if (choice == 1) {
      // Option 1: Use Current GPS
      setState(() => _isLoadingLoc = true);
      try {
        Position pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        finalPosition = LatLng(pos.latitude, pos.longitude);
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Could not fetch GPS.")));
      }
      setState(() => _isLoadingLoc = false);
    } else if (choice == 2) {
      // Option 2: Open Map Picker
      if (mounted) {
        finalPosition = await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => LocationPickerScreen(targetName: key)));
      }
    }

    // Save it if we got a result!
    if (finalPosition != null) {
      await prefs.setDouble('${key}_lat', finalPosition.latitude);
      await prefs.setDouble('${key}_lng', finalPosition.longitude);
      return finalPosition;
    }

    return null;
  }

  void _startBroadcast() async {
    LatLng? targetDest;
    String targetName = "";

    if (_selectedDestinationIndex > 0) {
      String key = _destinations[_selectedDestinationIndex];
      targetDest = await _getOrSetLocation(key);
      if (targetDest == null) {
        // User cancelled setting the location, reset to "None"
        setState(() => _selectedDestinationIndex = 0);
        return;
      }
      targetName = key;
    }

    if (mounted) {
      Navigator.pop(context, {
        'duration': _durations[_selectedDurationIndex],
        'destination': targetDest,
        'destName': targetName,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 24),
          Text("Configure Live Tracking",
              style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          // DURATION
          Text("Tracking Duration",
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_durations.length, (index) {
                final isSelected = _selectedDurationIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDurationIndex = index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isSelected
                              ? const Color(0xFF38BDF8)
                              : Colors.white12),
                    ),
                    child: Text(
                      _durationLabels[index],
                      style: TextStyle(
                          color: isSelected
                              ? const Color(0xFF0F172A)
                              : Colors.white,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal),
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 32),

          // DESTINATION (GEOFENCING)
          Text("Auto-Notify on Arrival",
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            children: List.generate(_destinations.length, (index) {
              final isSelected = _selectedDestinationIndex == index;
              return Expanded(
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _selectedDestinationIndex = index),
                  child: Container(
                    margin: EdgeInsets.only(right: index == 2 ? 0 : 12),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF34D399).withValues(alpha: 0.2)
                          : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isSelected
                              ? const Color(0xFF34D399)
                              : Colors.white12),
                    ),
                    child: Column(
                      children: [
                        Icon(_destIcons[index],
                            color: isSelected
                                ? const Color(0xFF34D399)
                                : Colors.white54,
                            size: 24),
                        const SizedBox(height: 8),
                        Text(_destinations[index],
                            style: TextStyle(
                                color: isSelected
                                    ? const Color(0xFF34D399)
                                    : Colors.white54,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 40),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoadingLoc ? null : _startBroadcast,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF43F5E),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoadingLoc
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text("START BROADCAST",
                      style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
