import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../services/incident_repository.dart';

class IncidentForumScreen extends StatelessWidget {
  const IncidentForumScreen({super.key});

  String _formatTime(DateTime? timestamp) {
    if (timestamp == null) return "Just now";
    final date = timestamp;
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) return "${diff.inMinutes} mins ago";
    if (diff.inHours < 24) return "${diff.inHours} hours ago";
    return "${diff.inDays} days ago";
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'Fire': return Icons.local_fire_department;
      case 'Flood': return Icons.flood;
      case 'Road Hazard': return Icons.warning_amber_rounded;
      case 'Emergency': return Icons.emergency;
      default: return Icons.visibility;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'Fire': return const Color(0xFFF97316);
      case 'Flood': return const Color(0xFF38BDF8);
      case 'Road Hazard': return const Color(0xFFEAB308);
      case 'Emergency': return const Color(0xFFEF4444);
      default: return const Color(0xFFF43F5E);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: const Color(0xFF020617),
        elevation: 0,
        title: Text("Community Forum",
            style: GoogleFonts.outfit(
                color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<CommunityIncident>>(
        stream: IncidentRepository().watchIncidents(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(
                child: Text("Error: ${snapshot.error}",
                    style: GoogleFonts.outfit(color: Colors.red)));
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF38BDF8)));

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.forum_outlined,
                      size: 80, color: Colors.white24),
                  const SizedBox(height: 16),
                  Text("No recent incidents reported.",
                      style: GoogleFonts.outfit(
                          color: Colors.white54, fontSize: 18)),
                  const SizedBox(height: 8),
                  Text("Your area is looking safe!",
                      style:
                          GoogleFonts.outfit(color: const Color(0xFF34D399))),
                ],
              ),
            );
          }

          final incidents = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: incidents.length,
            itemBuilder: (context, index) {
              final incident = incidents[index];
              final lat = incident.latitude;
              final lng = incident.longitude;
              final timestamp = incident.reportedAt;
              final type = incident.type;

              final iconColor = _getColorForType(type);
              final iconData = _getIconForType(type);

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: iconColor.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(iconData, color: iconColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(type,
                                  style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              Text(_formatTime(timestamp),
                                  style: GoogleFonts.outfit(
                                      color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(color: Colors.white10, height: 1),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: Colors.white38, size: 14),
                        const SizedBox(width: 6),
                        Text(
                            "Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}",
                            style: GoogleFonts.outfit(
                                color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
