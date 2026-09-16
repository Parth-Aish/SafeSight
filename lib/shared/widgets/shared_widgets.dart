import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: GoogleFonts.outfit(
            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white));
  }
}

class QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const QuickActionCard(
      {super.key,
      required this.icon,
      required this.label,
      required this.color,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: onTap,
        child: Column(children: [
          Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.05))),
              child: Icon(icon, color: color, size: 28)),
          const SizedBox(height: 8),
          Text(label,
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12))
        ]));
  }
}

class SafeZoneCard extends StatelessWidget {
  final String name;
  final String type;
  final String distance;
  final IconData icon;
  final String rating;
  final Color? color;
  final LatLng? destination;

  const SafeZoneCard(
      {super.key,
      required this.name,
      required this.type,
      required this.distance,
      required this.icon,
      required this.rating,
      this.color,
      this.destination});

  Future<void> _launchGoogleMaps(BuildContext context) async {
    if (destination == null) return;
    final Uri googleMapsUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${destination!.latitude},${destination!.longitude}&travelmode=driving');
    try {
      if (!await launchUrl(googleMapsUrl,
          mode: LaunchMode.externalApplication)) {
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Could not open Google Maps.")));
      }
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to launch navigation.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color:
                      (color ?? const Color(0xFF38BDF8)).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon,
                  color: color ?? const Color(0xFF38BDF8), size: 22)),
          Text(distance,
              style: const TextStyle(
                  color: Color(0xFF34D399),
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ]),
        const Spacer(),
        Text(name,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        Text(type, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 36,
          child: ElevatedButton.icon(
            onPressed: () => _launchGoogleMaps(context),
            icon: const Icon(Icons.navigation, size: 14),
            label: const Text("Start Direction",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0),
          ),
        )
      ]),
    );
  }
}

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const SettingsTile(
      {super.key, required this.icon, required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: onTap,
        child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.05))),
            child: Row(children: [
              Icon(icon, color: Colors.white70),
              const SizedBox(width: 16),
              Text(title,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 16)),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white24, size: 14)
            ])));
  }
}
