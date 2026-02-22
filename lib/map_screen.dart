import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart'; // REQUIRED: flutter pub add url_launcher

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with AutomaticKeepAliveClientMixin {
  final MapController _mapController = MapController();
  late PageController _pageController;

  // ---------------------------------------------------------------------------
  // GLOBAL CACHE (Zomato-Style Persistence Across Tabs)
  // ---------------------------------------------------------------------------
  static LatLng? _cachedPosition;
  static List<MarkerData>? _cachedMarkerData;
  static int _selectedCardIndex = 0; 

  // State
  LatLng _currentPosition = const LatLng(30.7333, 76.7794); 
  bool _isLoading = true;
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  bool _isMapReady = false;
  LatLng? _activeDestination; // To track the active route destination

  @override
  bool get wantKeepAlive => true; // Forces Flutter to NEVER destroy this tab's memory

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85, initialPage: _selectedCardIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_cachedPosition != null && _cachedMarkerData != null) {
        _currentPosition = _cachedPosition!;
        _updateMarkers();
        setState(() => _isLoading = false);
      } else {
        _fastInitialLoad();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onMapReady() {
    if (mounted) {
      setState(() => _isMapReady = true);
      _mapController.move(_currentPosition, 14.5);
    }
  }

  // ---------------------------------------------------------------------------
  // 1. GPS LOGIC (Fast Initial Load & Manual Refresh)
  // ---------------------------------------------------------------------------
  Future<bool> _checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorSnackBar("Location services are disabled.");
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorSnackBar("Location permissions denied.");
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showErrorSnackBar("Location permissions permanently denied.");
      return false;
    }
    
    return true;
  }

  Future<void> _fastInitialLoad() async {
    setState(() => _isLoading = true);

    bool hasPerms = await _checkPermissions();
    if (!hasPerms) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        _currentPosition = LatLng(lastKnown.latitude, lastKnown.longitude);
        if (_isMapReady) _mapController.move(_currentPosition, 14.5);
        await _fetchRealSafeZones(_currentPosition);
      }
    } catch (_) {}

    try {
      Position fresh = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );

      LatLng freshPos = LatLng(fresh.latitude, fresh.longitude);
      double dist = const Distance().as(LengthUnit.Meter, _currentPosition, freshPos);

      if (dist > 100 || _cachedMarkerData == null) {
        _currentPosition = freshPos;
        if (_isMapReady) _mapController.move(_currentPosition, 14.5);
        await _fetchRealSafeZones(_currentPosition);
      }
    } catch (e) {
      if (_cachedMarkerData == null && mounted) {
        _showErrorSnackBar("Could not get GPS lock.");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forceCurrentLocation() async {
    setState(() => _isLoading = true);

    bool hasPerms = await _checkPermissions();
    if (!hasPerms) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      Position fresh = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high, 
        timeLimit: const Duration(seconds: 10),
      );
      
      _currentPosition = LatLng(fresh.latitude, fresh.longitude);
      if (_isMapReady) _mapController.move(_currentPosition, 14.5);
      
      await _fetchRealSafeZones(_currentPosition);
    } catch (e) {
      _showErrorSnackBar("Could not establish a precise GPS connection.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // 2. FETCH REAL DATA
  // ---------------------------------------------------------------------------
  Future<void> _fetchRealSafeZones(LatLng center) async {
    try {
      final String overpassUrl = 
          'https://overpass-api.de/api/interpreter?data=[out:json][timeout:15];'
          '('
          'node["amenity"~"police|hospital|pharmacy|cafe|fast_food|marketplace|public_building"](around:2500,${center.latitude},${center.longitude});'
          'way["shop"~"mall"](around:2500,${center.latitude},${center.longitude});'
          ');'
          'out center;';

      final response = await http.get(Uri.parse(overpassUrl));

      if (response.statusCode == 200) {
        final List<MarkerData> markerDataList = await compute(_parseOverpassResponse, {
          'body': response.body,
          'centerLat': center.latitude,
          'centerLng': center.longitude,
        });

        _cachedPosition = center;
        _cachedMarkerData = markerDataList;
        _selectedCardIndex = markerDataList.isNotEmpty ? 0 : -1; 

        if (mounted) {
          _buildMarkersFromData(markerDataList, center);
          
          if (_pageController.hasClients && markerDataList.isNotEmpty) {
            _pageController.jumpToPage(0);
          }
        }
      }
    } catch (e) {
      debugPrint("API Error: $e");
    }
  }

  void _buildMarkersFromData(List<MarkerData> dataList, LatLng center) {
    _updateMarkers();
  }

  void _updateMarkers() {
    if (_cachedMarkerData == null) return;
    
    final List<Marker> newMarkers = [];

    // User Marker
    newMarkers.add(
      Marker(
        key: const Key('user_marker'),
        point: _currentPosition,
        width: 60,
        height: 60,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.my_location, color: Color(0xFF38BDF8), size: 28),
        ),
      ),
    );

    // Safe Zone Markers
    for (int i = 0; i < _cachedMarkerData!.length; i++) {
      final data = _cachedMarkerData![i];
      final isSelected = _selectedCardIndex == i;

      newMarkers.add(
        Marker(
          point: data.position,
          width: isSelected ? 55 : 44,
          height: isSelected ? 55 : 44,
          child: GestureDetector(
            onTap: () => _onMarkerTapped(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected ? data.color : const Color(0xFF1E293B), 
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? Colors.white : data.color, width: isSelected ? 3 : 2),
                boxShadow: isSelected ? [BoxShadow(color: data.color.withValues(alpha: 0.5), blurRadius: 10)] : [],
              ),
              child: Icon(data.icon, color: isSelected ? Colors.white : data.color, size: isSelected ? 24 : 18),
            ),
          ),
        ),
      );
    }

    setState(() {
      _markers = newMarkers;
    });
  }

  void _onMarkerTapped(int index) {
    setState(() => _selectedCardIndex = index);
    _updateMarkers(); 
    
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    _mapController.move(_cachedMarkerData![index].position, 15.5);
  }

  // ---------------------------------------------------------------------------
  // 3. GOOGLE MAPS INTEGRATION & ROUTING
  // ---------------------------------------------------------------------------
  Future<void> _launchGoogleMaps(LatLng destination) async {
    final Uri googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${destination.latitude},${destination.longitude}&travelmode=driving'
    );
    
    try {
      if (!await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication)) {
        _showErrorSnackBar("Could not open Google Maps.");
      }
    } catch (e) {
      debugPrint("Error launching Maps: $e");
      _showErrorSnackBar("Failed to launch navigation.");
    }
  }

  Future<void> _fetchRoutePath(LatLng destination) async {
    setState(() => _isLoading = true);

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${_currentPosition.longitude},${_currentPosition.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson'
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<LatLng> routePoints = await compute(_parseRouteResponse, response.body);

        if (mounted) {
          setState(() {
            _polylines = [
              Polyline(
                points: routePoints,
                strokeWidth: 5.0,
                color: const Color(0xFF38BDF8),
              ),
            ];
            _activeDestination = destination;
          });
          
          if (_isMapReady) {
            final bounds = LatLngBounds.fromPoints(routePoints);
            _mapController.fitCamera(
              CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Routing Error: $e");
      _showErrorSnackBar("Route calculation failed.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _cancelNavigation() {
    setState(() {
      _polylines.clear();
      _activeDestination = null;
    });
    _mapController.move(_currentPosition, 14.5);
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final double topPadding = MediaQuery.of(context).padding.top + 16;
    final bool hasData = _cachedMarkerData != null && _cachedMarkerData!.isNotEmpty;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition,
              initialZoom: 14.5,
              minZoom: 4.0, 
              maxZoom: 18.0, 
              onMapReady: _onMapReady,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.safesight',
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _currentPosition,
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
                    borderColor: const Color(0xFF38BDF8).withValues(alpha: 0.5),
                    borderStrokeWidth: 2,
                    useRadiusInMeter: true,
                    radius: 2500, 
                  ),
                ],
              ),
              PolylineLayer(polylines: _polylines),
              MarkerLayer(markers: _markers),
            ],
          ),
          
          // SEARCH BAR 
          Positioned(
            top: topPadding, 
            left: 20, 
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.white54),
                  const SizedBox(width: 12),
                  Expanded(child: Text("Search Safe Zones...", style: GoogleFonts.outfit(color: Colors.white54))),
                ],
              ),
            ),
          ),

          // ACTIVE NAVIGATION CHIP
          if (_polylines.isNotEmpty)
            Positioned(
              top: topPadding + 60,
              left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34D399),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.route, color: Color(0xFF0F172A), size: 16),
                      const SizedBox(width: 8),
                      Text("Route Preview", style: GoogleFonts.outfit(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                      if (_activeDestination != null) ...[
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => _launchGoogleMaps(_activeDestination!),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.navigation, color: Color(0xFF34D399), size: 12),
                                const SizedBox(width: 4),
                                Text("GO", style: GoogleFonts.outfit(color: const Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _cancelNavigation,
                        child: const Icon(Icons.cancel, color: Color(0xFF0F172A), size: 22),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // HORIZONTAL CARDS VIEWER 
          if (hasData)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              height: 140,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _selectedCardIndex = index);
                  _updateMarkers(); 
                  _mapController.move(_cachedMarkerData![index].position, 15.5);
                },
                itemCount: _cachedMarkerData!.length,
                itemBuilder: (context, index) {
                  final data = _cachedMarkerData![index];
                  final isSelected = _selectedCardIndex == index;
                  
                  final double distMeters = const Distance().as(LengthUnit.Meter, _currentPosition, data.position);
                  String distString = distMeters < 1000 
                      ? "${distMeters.toStringAsFixed(0)} m" 
                      : "${(distMeters / 1000).toStringAsFixed(1)} km";

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: EdgeInsets.symmetric(
                      horizontal: 8.0, 
                      vertical: isSelected ? 0 : 10.0, 
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF38BDF8) : Colors.white.withValues(alpha: 0.05),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected 
                          ? [BoxShadow(color: const Color(0xFF38BDF8).withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 5))]
                          : const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           Row(
                             children: [
                               Container(
                                 padding: const EdgeInsets.all(10),
                                 decoration: BoxDecoration(
                                   color: data.color.withValues(alpha: 0.2),
                                   borderRadius: BorderRadius.circular(12),
                                 ),
                                 child: Icon(data.icon, color: data.color, size: 24),
                               ),
                               const SizedBox(width: 12),
                               Expanded(
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Text(data.name, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                                     Text(data.type.toUpperCase(), style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11)),
                                   ],
                                 ),
                               ),
                               Text(distString, style: GoogleFonts.outfit(color: const Color(0xFF34D399), fontWeight: FontWeight.bold)),
                             ],
                           ),
                           Row(
                             children: [
                               Expanded(
                                 child: SizedBox(
                                   height: 40,
                                   child: ElevatedButton.icon(
                                     onPressed: () => _fetchRoutePath(data.position),
                                     icon: const Icon(Icons.route, size: 16),
                                     label: const Text("Show Route", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                     style: ElevatedButton.styleFrom(
                                       backgroundColor: const Color(0xFF1E293B),
                                       foregroundColor: const Color(0xFF38BDF8),
                                       side: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                       elevation: 0,
                                       padding: EdgeInsets.zero,
                                     ),
                                   ),
                                 ),
                               ),
                               const SizedBox(width: 8),
                               Expanded(
                                 child: SizedBox(
                                   height: 40,
                                   child: ElevatedButton.icon(
                                     onPressed: () => _launchGoogleMaps(data.position),
                                     icon: const Icon(Icons.navigation, size: 16),
                                     label: const Text("Start (Maps)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                     style: ElevatedButton.styleFrom(
                                       backgroundColor: const Color(0xFF38BDF8),
                                       foregroundColor: const Color(0xFF0F172A),
                                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                       elevation: 0,
                                       padding: EdgeInsets.zero,
                                     ),
                                   ),
                                 ),
                               ),
                             ],
                           ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // RE-CENTER BUTTON 
          Positioned(
            bottom: hasData ? 260 : 120, 
            right: 20,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: FloatingActionButton(
                backgroundColor: const Color(0xFF38BDF8),
                onPressed: () => _forceCurrentLocation(),
                child: const Icon(Icons.my_location, color: Color(0xFF020617)),
              ),
            ),
          ),

          // LOADING PILL
          if (_isLoading)
            Positioned(
              top: topPadding + 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8))),
                      const SizedBox(width: 8),
                      Text("Updating Location...", style: GoogleFonts.outfit(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ISOLATE HELPERS (Background Thread)
// -----------------------------------------------------------------------------
class MarkerData {
  final String name;
  final String type;
  final LatLng position;
  final IconData icon;
  final Color color;

  MarkerData({required this.name, required this.type, required this.position, required this.icon, required this.color});
}

// Parses JSON from Overpass into Dart objects
List<MarkerData> _parseOverpassResponse(Map<String, dynamic> params) {
  final String body = params['body'];
  final double centerLat = params['centerLat'];
  final double centerLng = params['centerLng'];
  final LatLng center = LatLng(centerLat, centerLng);

  final data = json.decode(body);
  final List elements = data['elements'] ?? [];
  
  elements.sort((a, b) {
    final latA = a['lat'] ?? a['center']?['lat'] ?? 0.0;
    final lonA = a['lon'] ?? a['center']?['lon'] ?? 0.0;
    final latB = b['lat'] ?? b['center']?['lat'] ?? 0.0;
    final lonB = b['lon'] ?? b['center']?['lon'] ?? 0.0;
    
    final distA = (latA - center.latitude) * (latA - center.latitude) + (lonA - center.longitude) * (lonA - center.longitude);
    final distB = (latB - center.latitude) * (latB - center.latitude) + (lonB - center.longitude) * (lonB - center.longitude);
    return distA.compareTo(distB);
  });

  final limitedElements = elements.take(150);
  final List<MarkerData> results = [];

  for (var element in limitedElements) {
    final lat = element['lat'] ?? element['center']?['lat'];
    final lon = element['lon'] ?? element['center']?['lon'];
    
    if (lat == null || lon == null) continue;

    final tags = element['tags'] ?? {};
    final name = tags['name'] ?? 'Safe Zone';
    
    final amenity = tags['amenity'];
    final shop = tags['shop'];
    final type = amenity ?? shop ?? 'unknown';

    IconData icon;
    Color color;

    if (type == 'police') {
      icon = Icons.local_police;
      color = const Color(0xFF3B82F6);
    } else if (type == 'hospital' || type == 'pharmacy' || type == 'clinic') {
      icon = Icons.local_hospital;
      color = const Color(0xFFF43F5E);
    } else if (type == 'mall' || type == 'supermarket' || type == 'department_store') {
      icon = Icons.storefront;
      color = const Color(0xFFA855F7); 
    } else {
      icon = Icons.local_cafe; 
      color = const Color(0xFFEAB308); 
    }

    results.add(MarkerData(
      name: name,
      type: type,
      position: LatLng(lat, lon),
      icon: icon,
      color: color,
    ));
  }
  return results;
}

// Parses JSON from OSRM into Route Points
List<LatLng> _parseRouteResponse(String body) {
  final data = json.decode(body);
  if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
    final geometry = data['routes'][0]['geometry'];
    final coordinates = geometry['coordinates'] as List;
    return coordinates.map((point) {
      return LatLng((point as List)[1].toDouble(), point[0].toDouble());
    }).toList();
  }
  return [];
}