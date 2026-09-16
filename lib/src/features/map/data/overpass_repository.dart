import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:safesight/features/safety_scan/domain/models/safe_zone.dart';

// ---------------------------------------------------------------------------
// Overpass Repository
// ---------------------------------------------------------------------------
// Clean wrapper for querying the Overpass API for verified emergency
// infrastructure (police stations, hospitals, clinics).
//
// Features:
//   - Queries exclusively for verified emergency tags
//   - Results cached in memory with 30-minute TTL per geohash-5 cell
//   - Proper User-Agent header for attribution compliance
//   - Response parsing in isolate-ready format
// ---------------------------------------------------------------------------

class OverpassRepository {
  final http.Client _client;
  static const String _endpoint = 'https://overpass-api.de/api/interpreter';
  static const String _userAgent = 'SafeSight/1.0 (personal safety app)';

  // Cache: geohash → (results, expiry)
  final Map<String, (List<SafeZone>, DateTime)> _cache = {};
  static const Duration _cacheTtl = Duration(minutes: 30);

  OverpassRepository({http.Client? client})
      : _client = client ?? http.Client();

  /// Queries Overpass for verified emergency infrastructure near [center].
  ///
  /// Returns police stations, hospitals, and clinics within [radiusMeters].
  /// Results are cached for 30 minutes per geohash-5 cell.
  Future<List<SafeZone>> fetchNearbyEmergencyZones({
    required LatLng center,
    double radiusMeters = 2000,
  }) async {
    final cacheKey = _geohash5(center);
    final cached = _cache[cacheKey];
    if (cached != null && DateTime.now().isBefore(cached.$2)) {
      debugPrint('OverpassRepo: cache hit for $cacheKey (${cached.$1.length} zones)');
      return cached.$1;
    }

    try {
      final query = _buildQuery(center, radiusMeters);
      final response = await _client.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': _userAgent,
        },
        body: 'data=${Uri.encodeComponent(query)}',
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('OverpassRepo: HTTP ${response.statusCode}');
        return cached?.$1 ?? [];
      }

      final json = jsonDecode(response.body);
      final elements = json['elements'] as List<dynamic>? ?? [];
      final zones = _parseElements(elements, center);

      // Cache results
      _cache[cacheKey] = (zones, DateTime.now().add(_cacheTtl));
      debugPrint('OverpassRepo: fetched ${zones.length} zones for $cacheKey');
      return zones;
    } catch (e) {
      debugPrint('OverpassRepo: query failed: $e');
      return cached?.$1 ?? [];
    }
  }

  /// Build Overpass QL query for verified emergency infrastructure.
  String _buildQuery(LatLng center, double radius) {
    return '''
[out:json][timeout:10];
(
  node["amenity"="police"](around:$radius,${center.latitude},${center.longitude});
  node["amenity"="hospital"](around:$radius,${center.latitude},${center.longitude});
  node["amenity"="clinic"](around:$radius,${center.latitude},${center.longitude});
  node["healthcare"="hospital"](around:$radius,${center.latitude},${center.longitude});
  way["amenity"="police"](around:$radius,${center.latitude},${center.longitude});
  way["amenity"="hospital"](around:$radius,${center.latitude},${center.longitude});
);
out center;
''';
  }

  List<SafeZone> _parseElements(List<dynamic> elements, LatLng center) {
    final zones = <SafeZone>[];
    final seenIds = <String>{};

    for (final element in elements) {
      final id = element['id']?.toString() ?? '';
      if (seenIds.contains(id)) continue;
      seenIds.add(id);

      final tags = element['tags'] as Map<String, dynamic>? ?? {};
      final amenity = tags['amenity'] as String?;
      final healthcare = tags['healthcare'] as String?;
      final name = tags['name'] as String? ?? _defaultName(amenity, healthcare);

      SafeZoneType? type;
      if (amenity == 'police') {
        type = SafeZoneType.police;
      } else if (amenity == 'hospital' || healthcare == 'hospital') {
        type = SafeZoneType.hospital;
      } else if (amenity == 'clinic') {
        type = SafeZoneType.hospital; // Clinics mapped to hospital type
      }

      if (type == null) continue;

      // Extract position (node vs way center)
      double? lat, lng;
      if (element['type'] == 'node') {
        lat = (element['lat'] as num?)?.toDouble();
        lng = (element['lon'] as num?)?.toDouble();
      } else {
        final centerData = element['center'] as Map<String, dynamic>?;
        lat = (centerData?['lat'] as num?)?.toDouble();
        lng = (centerData?['lon'] as num?)?.toDouble();
      }

      if (lat == null || lng == null) continue;

      zones.add(SafeZone(
        id: 'osm_$id',
        name: name,
        type: type,
        position: LatLng(lat, lng),
        isVerified: true,
      ));
    }

    return zones;
  }

  String _defaultName(String? amenity, String? healthcare) {
    if (amenity == 'police') return 'Police Station';
    if (amenity == 'hospital' || healthcare == 'hospital') return 'Hospital';
    if (amenity == 'clinic') return 'Medical Clinic';
    return 'Emergency Service';
  }

  String _geohash5(LatLng pos) {
    return '${pos.latitude.toStringAsFixed(2)},${pos.longitude.toStringAsFixed(2)}';
  }
}
