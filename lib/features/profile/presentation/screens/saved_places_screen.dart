import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';

// FIX: Updated path to include one more level (../../../../)
import '../../../../shared/widgets/location_picker_screen.dart';

class SavedPlacesScreen extends StatefulWidget {
  const SavedPlacesScreen({super.key});

  @override
  State<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends State<SavedPlacesScreen> {
  LatLng? _homeLocation;
  LatLng? _officeLocation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedPlaces();
  }

  Future<void> _loadSavedPlaces() async {
    final prefs = await SharedPreferences.getInstance();

    final homeLat = prefs.getDouble('Home_lat');
    final homeLng = prefs.getDouble('Home_lng');
    final officeLat = prefs.getDouble('Office_lat');
    final officeLng = prefs.getDouble('Office_lng');

    if (mounted) {
      setState(() {
        if (homeLat != null && homeLng != null)
          _homeLocation = LatLng(homeLat, homeLng);
        if (officeLat != null && officeLng != null)
          _officeLocation = LatLng(officeLat, officeLng);
        _isLoading = false;
      });
    }
  }

  Future<void> _updateLocation(String key) async {
    final LatLng? result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => LocationPickerScreen(targetName: key)));

    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('${key}_lat', result.latitude);
      await prefs.setDouble('${key}_lng', result.longitude);

      _loadSavedPlaces();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("$key location successfully updated!",
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF34D399),
        ));
      }
    }
  }

  Future<void> _clearLocation(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${key}_lat');
    await prefs.remove('${key}_lng');
    _loadSavedPlaces();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: const Color(0xFF020617),
        elevation: 0,
        title: Text("Saved Places",
            style: GoogleFonts.outfit(
                color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      "Configure your frequent destinations here. When you start an SOS Broadcast towards one of these places, the app will automatically notify your contacts upon your safe arrival.",
                      style: GoogleFonts.outfit(
                          color: Colors.white54, fontSize: 14)),
                  const SizedBox(height: 32),
                  _buildPlaceCard(
                    title: "Home",
                    icon: Icons.home,
                    location: _homeLocation,
                    onEdit: () => _updateLocation("Home"),
                    onClear: () => _clearLocation("Home"),
                  ),
                  const SizedBox(height: 16),
                  _buildPlaceCard(
                    title: "Office",
                    icon: Icons.work,
                    location: _officeLocation,
                    onEdit: () => _updateLocation("Office"),
                    onClear: () => _clearLocation("Office"),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPlaceCard(
      {required String title,
      required IconData icon,
      required LatLng? location,
      required VoidCallback onEdit,
      required VoidCallback onClear}) {
    final bool isConfigured = location != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isConfigured
                ? const Color(0xFF38BDF8).withValues(alpha: 0.3)
                : Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isConfigured
                      ? const Color(0xFF38BDF8).withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon,
                    color:
                        isConfigured ? const Color(0xFF38BDF8) : Colors.white54,
                    size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                    const SizedBox(height: 4),
                    Text(isConfigured ? "Secured Location" : "Not configured",
                        style: GoogleFonts.outfit(
                            color: isConfigured
                                ? const Color(0xFF34D399)
                                : Colors.white38,
                            fontSize: 13,
                            fontWeight: isConfigured
                                ? FontWeight.bold
                                : FontWeight.normal)),
                  ],
                ),
              ),
              if (isConfigured)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Color(0xFFF43F5E)),
                  onPressed: onClear,
                  tooltip: "Remove Address",
                )
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onEdit,
              icon: Icon(
                  isConfigured
                      ? Icons.edit_location_alt
                      : Icons.add_location_alt,
                  size: 18),
              label: Text(isConfigured ? "UPDATE ON MAP" : "SET ON MAP"),
              style: ElevatedButton.styleFrom(
                backgroundColor: isConfigured
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF38BDF8),
                foregroundColor: isConfigured
                    ? const Color(0xFF38BDF8)
                    : const Color(0xFF0F172A),
                side: BorderSide(
                    color: isConfigured
                        ? const Color(0xFF38BDF8).withValues(alpha: 0.5)
                        : Colors.transparent),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          )
        ],
      ),
    );
  }
}
