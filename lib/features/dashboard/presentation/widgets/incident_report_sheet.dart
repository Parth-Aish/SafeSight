import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../../../services/safety_service.dart';

class IncidentReportSheet extends ConsumerStatefulWidget {
  const IncidentReportSheet({super.key});

  @override
  ConsumerState<IncidentReportSheet> createState() =>
      _IncidentReportSheetState();
}

class _IncidentReportSheetState extends ConsumerState<IncidentReportSheet> {
  int _selectedIndex = -1;
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _incidentTypes = [
    {
      "label": "Suspicious Activity",
      "icon": Icons.visibility,
      "color": const Color(0xFFEAB308)
    },
    {
      "label": "Fire",
      "icon": Icons.local_fire_department,
      "color": const Color(0xFFF97316)
    },
    {
      "label": "Flood",
      "icon": Icons.flood,
      "color": const Color(0xFF38BDF8)
    },
    {
      "label": "Road Hazard",
      "icon": Icons.warning_amber_rounded,
      "color": const Color(0xFFEAB308)
    },
    {
      "label": "Emergency",
      "icon": Icons.emergency,
      "color": const Color(0xFFEF4444)
    },
    {
      "label": "Other Danger",
      "icon": Icons.error_outline,
      "color": const Color(0xFFF43F5E)
    },
  ];

  Future<void> _submitReport() async {
    if (_selectedIndex == -1) return;

    setState(() => _isSubmitting = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      final String incidentType = _incidentTypes[_selectedIndex]["label"];
      await ref
          .read(safetyServiceProvider)
          .reportIncident(pos, type: incidentType);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Alert broadcasted to nearby users securely.",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Color(0xFF34D399),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Failed to submit. Check GPS & network connection.",
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 24),
          Text("Report Incident",
              style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
              "Select the type of incident to alert the SafeSight network. Your identity remains completely anonymous.",
              style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.5,
            ),
            itemCount: _incidentTypes.length,
            itemBuilder: (context, index) {
              final isSelected = _selectedIndex == index;
              final data = _incidentTypes[index];
              return GestureDetector(
                onTap: () => setState(() => _selectedIndex = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? data["color"].withValues(alpha: 0.2)
                        : const Color(0xFF1E293B),
                    border: Border.all(
                        color: isSelected
                            ? data["color"]
                            : Colors.white.withValues(alpha: 0.05),
                        width: isSelected ? 2 : 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(data["icon"],
                          color: isSelected ? data["color"] : Colors.white54,
                          size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(data["label"],
                              style: GoogleFonts.outfit(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal))),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: (_selectedIndex == -1 || _isSubmitting)
                  ? null
                  : _submitReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF43F5E),
                disabledBackgroundColor: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text("BROADCAST ALERT",
                      style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
