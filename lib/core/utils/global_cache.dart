import 'package:latlong2/latlong.dart';

class GlobalMapCache {
  // Stores the safe zones found on the map
  static List<dynamic> cachedZones = [];

  // Stores the user's last known precise location
  static LatLng? userLocation;
}
