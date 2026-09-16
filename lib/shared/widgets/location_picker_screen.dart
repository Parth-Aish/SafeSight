import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class LocationPickerScreen extends StatefulWidget {
  final String targetName; // e.g., "Home" or "Office"
  const LocationPickerScreen({super.key, required this.targetName});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  LatLng _mapCenter =
      const LatLng(20.5937, 78.9629); // Default to India roughly
  bool _isLoading = true;
  bool _isSearching = false;
  List<dynamic> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          Position pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.medium);
          _mapCenter = LatLng(pos.latitude, pos.longitude);
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
      // Let the map build first, then move it
      Future.delayed(const Duration(milliseconds: 100), () {
        _mapController.move(_mapCenter, 15.0);
      });
    }
  }

  Future<void> _searchAddress(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=5');
      final response =
          await http.get(url, headers: {'User-Agent': 'SafeSightApp/1.0'});

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _searchResults = json.decode(response.body);
            _isSearching = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Search error: $e");
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _onSearchResultTapped(dynamic result) {
    final double lat = double.parse(result['lat']);
    final double lon = double.parse(result['lon']);
    final LatLng newPos = LatLng(lat, lon);

    setState(() {
      _searchResults = []; // Hide search results
      _searchController.text = result['display_name'].toString().split(',')[0];
      _mapCenter = newPos;
    });

    _mapController.move(newPos, 16.0);
    FocusScope.of(context).unfocus(); // Dismiss keyboard
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
        title: Text("Set ${widget.targetName} Location",
            style: GoogleFonts.outfit(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : Stack(
              children: [
                // 1. THE MAP
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _mapCenter,
                    initialZoom: 15.0,
                    onPositionChanged: (camera, hasGesture) {
                      if (hasGesture) {
                        _mapCenter = camera.center;
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.safesight',
                    ),
                  ],
                ),

                // 2. THE CENTER CROSSHAIR/PIN (Always stays in the middle)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(
                        bottom:
                            40.0), // Offset slightly to point exactly at center
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 10)
                            ],
                          ),
                          child: Text("Drop Pin Here",
                              style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const Icon(Icons.location_on,
                            color: Color(0xFFF43F5E), size: 40),
                      ],
                    ),
                  ),
                ),

                // 3. THE SEARCH BAR
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(color: Colors.black45, blurRadius: 10)
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Search an address...",
                            hintStyle: const TextStyle(color: Colors.white54),
                            prefixIcon:
                                const Icon(Icons.search, color: Colors.white54),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.clear,
                                  color: Colors.white54),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchResults = []);
                              },
                            ),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onSubmitted: _searchAddress,
                        ),
                      ),

                      // SEARCH RESULTS LIST
                      if (_isSearching)
                        Container(
                          margin: const EdgeInsets.only(
                              top:
                                  8), // FIX: Changed from .top(8) to .only(top: 8)
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(16)),
                          child: const Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFF38BDF8))),
                        )
                      else if (_searchResults.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(color: Colors.black54, blurRadius: 15)
                            ],
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _searchResults.length,
                            separatorBuilder: (context, index) => Divider(
                                color: Colors.white.withValues(alpha: 0.1),
                                height: 1),
                            itemBuilder: (context, index) {
                              final result = _searchResults[index];
                              return ListTile(
                                leading: const Icon(Icons.place,
                                    color: Color(0xFF38BDF8)),
                                title: Text(result['display_name'],
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 13),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                onTap: () => _onSearchResultTapped(result),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),

                // 4. BOTTOM CONFIRM BUTTON
                Positioned(
                  bottom: 30,
                  left: 20,
                  right: 20,
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        // Return the exact coordinates the map is currently centered on
                        Navigator.pop(context, _mapCenter);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38BDF8),
                        foregroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 10,
                      ),
                      child: Text("SET AS ${widget.targetName.toUpperCase()}",
                          style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 1)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
