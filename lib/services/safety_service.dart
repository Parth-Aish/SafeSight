import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../features/safety_scan/data/repositories/safety_repository.dart';
import 'incident_repository.dart';

final safetyServiceProvider = Provider<SafetyService>((ref) => SafetyService());

class SafetyReport {
  final double score;
  final String status;
  final String message;
  final Color color;
  final int newsCount;
  final int infraCount;
  final int crowdCount;

  const SafetyReport({
    required this.score,
    required this.status,
    required this.message,
    required this.color,
    required this.newsCount,
    required this.infraCount,
    required this.crowdCount,
  });
}

class SafetyService {
  final SafetyRepository _repository = SafetyRepository();
  final IncidentRepository _incidentRepository = IncidentRepository();

  Future<SafetyReport> analyzeLocation(
      {required Position pos, required String city}) async {
    final assessment = await _repository.assess(position: pos, city: city);
    return SafetyReport(
      score: assessment.score,
      status: assessment.status,
      message: '${assessment.summary} ${assessment.actionAdvice}',
      color: assessment.color,
      newsCount: assessment.newsCount,
      infraCount: 0,
      crowdCount: assessment.communityIncidentCount,
    );
  }

  Future<void> reportIncident(Position pos,
      {String type = 'Suspicious Activity'}) async {
    await _incidentRepository.report(
      position: LatLng(pos.latitude, pos.longitude),
      type: type,
    );
  }
}
