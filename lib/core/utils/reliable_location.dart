import 'package:geolocator/geolocator.dart';

Future<Position?> getReliableLocation() async {
  if (!await Geolocator.isLocationServiceEnabled()) return null;

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return null;
  }

  final lastKnown = await Geolocator.getLastKnownPosition();
  try {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 12),
    );
  } catch (_) {
    return lastKnown;
  }
}
