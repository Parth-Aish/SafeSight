import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../../../../../core/utils/global_cache.dart';
import '../../../../../../shared/widgets/shared_widgets.dart';

class DynamicSafeZoneList extends StatelessWidget {
  final List<dynamic> zones;

  const DynamicSafeZoneList({super.key, required this.zones});

  @override
  Widget build(BuildContext context) {
    if (zones.isEmpty) {
      return Container(
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.radar, color: Colors.white24, size: 32),
            const SizedBox(height: 8),
            Text("Open 'Nearby' tab to scan for safe zones",
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13)),
          ],
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: zones.length > 6 ? 6 : zones.length,
        itemBuilder: (context, index) {
          final zone = zones[index];
          String distanceText = "Nearby";
          if (GlobalMapCache.userLocation != null) {
            final double rawDistMeters = const Distance().as(
                LengthUnit.Meter, GlobalMapCache.userLocation!, zone.position);

            final double trueDistMeters = rawDistMeters * 1.35;

            distanceText = trueDistMeters < 1000
                ? "${trueDistMeters.toStringAsFixed(0)} m"
                : "${(trueDistMeters / 1000).toStringAsFixed(1)} km";
          }

          return SafeZoneCard(
            name: zone.name,
            type: zone.type.toUpperCase(),
            distance: distanceText,
            icon: zone.icon,
            rating: "4.9",
            color: zone.color,
            destination: zone.position,
          );
        },
      ),
    );
  }
}
