import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum SafeZoneType { police, hospital, pharmacy }

class SafeZone {
  final String id;
  final String name;
  final SafeZoneType type;
  final LatLng position;
  final bool isVerified;

  const SafeZone({
    required this.id,
    required this.name,
    required this.type,
    required this.position,
    this.isVerified = true,
  });

  IconData get icon => switch (type) {
        SafeZoneType.police => Icons.local_police,
        SafeZoneType.hospital => Icons.local_hospital,
        SafeZoneType.pharmacy => Icons.local_pharmacy,
      };

  Color get color => switch (type) {
        SafeZoneType.police => const Color(0xFF3B82F6),
        SafeZoneType.hospital => const Color(0xFFF43F5E),
        SafeZoneType.pharmacy => const Color(0xFF34D399),
      };
}
