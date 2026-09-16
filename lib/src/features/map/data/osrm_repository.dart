import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

// ---------------------------------------------------------------------------
// OSRM Repository
// ---------------------------------------------------------------------------
// Clean wrapper for the Open Source Routing Machine (OSRM) API.
// Used for route geometry (polyline) and navigation details.
//
// Endpoint: Public OSRM demo server (rate-limited).
// For production, configure a self-hosted OSRM instance.
// ---------------------------------------------------------------------------

/// Route geometry and metadata from OSRM.
class RouteGeometry {
  /// Decoded polyline points.
  final List<LatLng> polyline;

  /// Total route distance in meters.
  final double distanceMeters;

  /// Total route duration in seconds.
  final double durationSeconds;

  /// Human-readable summary.
  final String summary;

  const RouteGeometry({
    required this.polyline,
    required this.distanceMeters,
    required this.durationSeconds,
    this.summary = '',
  });
}

/// OSRM route query repository.
class OsrmRepository {
  final http.Client _client;
  static const String _baseUrl = 'https://router.project-osrm.org';
  static const String _userAgent = 'SafeSight/1.0';

  OsrmRepository({http.Client? client})
      : _client = client ?? http.Client();

  /// Get a walking route between origin and destination.
  ///
  /// Returns decoded polyline with distance and duration.
  Future<RouteGeometry?> getRoute({
    required LatLng origin,
    required LatLng destination,
    String profile = 'foot', // foot, car, bike
  }) async {
    try {
      final url =
          '$_baseUrl/route/v1/$profile/'
          '${origin.longitude},${origin.latitude};'
          '${destination.longitude},${destination.latitude}'
          '?overview=full&geometries=polyline&steps=false';

      final response = await _client.get(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('OSRM: HTTP ${response.statusCode}');
        return null;
      }

      final json = jsonDecode(response.body);
      final routes = json['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes[0] as Map<String, dynamic>;
      final geometry = route['geometry'] as String?;
      if (geometry == null) return null;

      return RouteGeometry(
        polyline: _decodePolyline(geometry),
        distanceMeters: (route['distance'] as num?)?.toDouble() ?? 0,
        durationSeconds: (route['duration'] as num?)?.toDouble() ?? 0,
        summary: (route['legs'] as List<dynamic>?)
                ?.map((l) => (l as Map<String, dynamic>)['summary'] ?? '')
                .join(' → ') ??
            '',
      );
    } catch (e) {
      debugPrint('OSRM: route query failed: $e');
      return null;
    }
  }

  /// Decodes a Google-encoded polyline string into LatLng points.
  static List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      // Decode latitude
      var shift = 0;
      var result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      // Decode longitude
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }
}
