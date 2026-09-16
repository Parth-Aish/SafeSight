import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:safesight/src/features/safety_scan/data/datasources/gemini_risk_datasource.dart';
import 'package:safesight/src/features/map/data/overpass_repository.dart';
import 'package:safesight/features/safety_scan/domain/models/safe_zone.dart';
import '../datasources/rss_news_data_source.dart';
import '../../domain/models/safety_assessment.dart';

class SafetyRepository {
  final RssNewsDataSource _newsSource;
  final FirebaseFirestore _firestore;
  final GeminiRiskDatasource _geminiRisk;
  final OverpassRepository _overpass;

  SafetyRepository({
    RssNewsDataSource? newsSource,
    FirebaseFirestore? firestore,
    GeminiRiskDatasource? geminiRisk,
    OverpassRepository? overpass,
  })  : _newsSource = newsSource ?? RssNewsDataSource(),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _geminiRisk = geminiRisk ?? GeminiRiskDatasource(),
        _overpass = overpass ?? OverpassRepository();

  Future<SafetyAssessment> assess({
    required Position position,
    required String city,
  }) async {
    // 1. Fetch data in parallel
    final headlinesFuture = _newsSource
        .fetchRecentHeadlines(city)
        .catchError((_) => <NewsHeadline>[]);
    final incidentsFuture = _fetchNearbyIncidentCount(position);
    final zonesFuture = _overpass.fetchNearbyEmergencyZones(
      center: LatLng(position.latitude, position.longitude),
    ).catchError((_) => <SafeZone>[]);

    final results = await Future.wait([
      headlinesFuture,
      incidentsFuture,
      zonesFuture,
    ]);

    final headlines = results[0] as List<NewsHeadline>;
    final incidentCount = results[1] as int;
    final zones = results[2] as List<SafeZone>;

    final policeCount = zones.where((z) => z.type == SafeZoneType.police).length;
    final hospitalCount =
        zones.where((z) => z.type == SafeZoneType.hospital).length;

    // 2. Query Gemini Risk AI
    final geminiAssessment = await _geminiRisk.assessRisk(
      latitude: position.latitude,
      longitude: position.longitude,
      city: city,
      newsHeadlines: headlines.map((h) => h.title).toList(),
      nearbyIncidentCount: incidentCount,
      policeStationCount: policeCount,
      hospitalCount: hospitalCount,
      hour: DateTime.now().hour,
    );

    // 3. Map to Domain Model
    final level = _mapRiskLevel(geminiAssessment.riskLevel, incidentCount);

    return SafetyAssessment(
      level: level,
      confidenceScore: 1.0 - geminiAssessment.riskIndex,
      summary: geminiAssessment.recommendation,
      actionAdvice: geminiAssessment.recommendation,
      hasRecentIncident: incidentCount > 0,
      newsCount: headlines.length,
      communityIncidentCount: incidentCount,
      assessedAt: geminiAssessment.assessedAt,
      factors: geminiAssessment.factors,
      aiModelVersion: geminiAssessment.modelVersion,
    );
  }

  SafetyLevel _mapRiskLevel(String geminiLevel, int incidentCount) {
    if (geminiLevel == 'CRITICAL' || geminiLevel == 'HIGH') {
      return SafetyLevel.alert;
    }
    if (geminiLevel == 'MODERATE' || incidentCount > 0) {
      return SafetyLevel.moderate;
    }
    return SafetyLevel.safe;
  }

  Future<int> _fetchNearbyIncidentCount(Position position) async {
    final cutoff =
        Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7)));
    try {
      final snapshot = await _firestore
          .collection('incidents')
          .where('timestamp', isGreaterThan: cutoff)
          .limit(200)
          .get();

      return snapshot.docs.where((doc) {
        final data = doc.data();
        final latitude = (data['lat'] as num?)?.toDouble();
        final longitude = (data['lng'] as num?)?.toDouble();
        if (latitude == null || longitude == null) return false;
        return Geolocator.distanceBetween(
              position.latitude,
              position.longitude,
              latitude,
              longitude,
            ) <=
            1500;
      }).length;
    } catch (_) {
      return 0;
    }
  }
}

