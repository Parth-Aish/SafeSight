import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// Gemini Risk Datasource
// ---------------------------------------------------------------------------
// Interfaces with Gemini 1.5 Flash via structured JSON schema to produce
// a deterministic risk index from nearby infrastructure and news data.
//
// Defaults to SAFE when:
//   - Gemini API key is not configured
//   - Gemini returns an error
//   - Network is unavailable
//
// Input: Overpass infrastructure, 7-day RSS headlines, community incidents,
//        time of day, population density estimate.
// Output: Structured RiskAssessment with factor breakdown.
//
// Cached for 15 minutes per geohash-6 cell.
// ---------------------------------------------------------------------------

/// Structured risk assessment from Gemini.
class GeminiRiskAssessment {
  final double riskIndex; // 0.0 (safe) to 1.0 (critical)
  final String riskLevel; // SAFE, LOW, MODERATE, HIGH, CRITICAL
  final List<RiskFactor> factors;
  final String recommendation;
  final String? modelVersion;
  final DateTime assessedAt;

  const GeminiRiskAssessment({
    required this.riskIndex,
    required this.riskLevel,
    this.factors = const [],
    required this.recommendation,
    this.modelVersion,
    required this.assessedAt,
  });

  factory GeminiRiskAssessment.safe() => GeminiRiskAssessment(
        riskIndex: 0.15,
        riskLevel: 'SAFE',
        recommendation:
            'No significant risk indicators detected. Stay aware of your surroundings.',
        assessedAt: DateTime.now(),
      );

  factory GeminiRiskAssessment.fromJson(Map<String, dynamic> json) {
    return GeminiRiskAssessment(
      riskIndex: (json['riskIndex'] as num?)?.toDouble() ?? 0.15,
      riskLevel: json['riskLevel'] as String? ?? 'SAFE',
      factors: (json['factors'] as List<dynamic>?)
              ?.map((f) => RiskFactor.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [],
      recommendation: json['recommendation'] as String? ??
          'No assessment available.',
      modelVersion: 'gemini-1.5-flash',
      assessedAt: DateTime.now(),
    );
  }
}

/// Individual risk factor from the assessment.
class RiskFactor {
  final String category;
  final String description;
  final double weight;

  const RiskFactor({
    required this.category,
    required this.description,
    required this.weight,
  });

  factory RiskFactor.fromJson(Map<String, dynamic> json) {
    return RiskFactor(
      category: json['category'] as String? ?? 'unknown',
      description: json['description'] as String? ?? '',
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'category': category,
        'description': description,
        'weight': weight,
      };
}

/// Gemini 1.5 Flash risk analysis datasource.
class GeminiRiskDatasource {
  final String? apiKey;
  final http.Client _client;

  // Cache: geohash-6 → (assessment, expiry)
  final Map<String, (GeminiRiskAssessment, DateTime)> _cache = {};
  static const Duration _cacheTtl = Duration(minutes: 15);

  GeminiRiskDatasource({
    this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Whether the Gemini API is configured.
  bool get isConfigured => apiKey != null && apiKey!.isNotEmpty;

  /// Assess risk for a location using Gemini 1.5 Flash.
  ///
  /// Returns [GeminiRiskAssessment.safe()] if Gemini is unavailable.
  Future<GeminiRiskAssessment> assessRisk({
    required double latitude,
    required double longitude,
    required String city,
    required List<String> newsHeadlines,
    required int nearbyIncidentCount,
    required int policeStationCount,
    required int hospitalCount,
    required int hour,
  }) async {
    if (!isConfigured) {
      debugPrint('GeminiRisk: API key not configured, defaulting to SAFE');
      return GeminiRiskAssessment.safe();
    }

    // Check cache
    final geohash = _simpleGeohash(latitude, longitude, precision: 6);
    final cached = _cache[geohash];
    if (cached != null && DateTime.now().isBefore(cached.$2)) {
      debugPrint('GeminiRisk: cache hit for $geohash');
      return cached.$1;
    }

    try {
      final prompt = _buildPrompt(
        city: city,
        headlines: newsHeadlines,
        incidents: nearbyIncidentCount,
        police: policeStationCount,
        hospitals: hospitalCount,
        hour: hour,
      );

      final response = await _client.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/'
          'gemini-1.5-flash:generateContent?key=$apiKey',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {
            'responseMimeType': 'application/json',
            'responseSchema': _responseSchema,
            'temperature': 0.1, // Low temperature for deterministic output
          },
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('GeminiRisk: HTTP ${response.statusCode}');
        return GeminiRiskAssessment.safe();
      }

      final body = jsonDecode(response.body);
      final text = body['candidates']?[0]?['content']?['parts']?[0]?['text'];
      if (text == null) return GeminiRiskAssessment.safe();

      final json = jsonDecode(text as String) as Map<String, dynamic>;
      final assessment = GeminiRiskAssessment.fromJson(json);

      // Cache result
      _cache[geohash] = (assessment, DateTime.now().add(_cacheTtl));

      debugPrint(
        'GeminiRisk: ${assessment.riskLevel} (${assessment.riskIndex.toStringAsFixed(2)}) '
        'for $city',
      );
      return assessment;
    } catch (e) {
      debugPrint('GeminiRisk: assessment failed: $e');
      return GeminiRiskAssessment.safe();
    }
  }

  String _buildPrompt({
    required String city,
    required List<String> headlines,
    required int incidents,
    required int police,
    required int hospitals,
    required int hour,
  }) {
    final headlineBlock = headlines.take(15).join('\n- ');

    return '''
You are a safety risk assessment AI. Analyze the following data about a location and produce a structured risk assessment.

Location: $city
Time: ${hour}:00 (24h format)
Nearby Infrastructure:
- Police stations within 2km: $police
- Hospitals within 2km: $hospitals

Community Incidents (last 7 days within 1.5km): $incidents

Recent News Headlines (last 7 days):
- $headlineBlock

Rules:
1. Default to SAFE if there is insufficient data.
2. Do NOT inflate risk based on city name alone.
3. Weight community incidents more heavily than news headlines.
4. More police/hospital infrastructure REDUCES risk.
5. Late night hours (22:00-05:00) increase risk slightly.
6. Be conservative — only mark HIGH or CRITICAL with strong evidence.

Produce a JSON response matching the schema exactly.''';
  }

  static const Map<String, dynamic> _responseSchema = {
    'type': 'object',
    'properties': {
      'riskIndex': {
        'type': 'number',
        'description': 'Risk score from 0.0 (safe) to 1.0 (critical)',
      },
      'riskLevel': {
        'type': 'string',
        'enum': ['SAFE', 'LOW', 'MODERATE', 'HIGH', 'CRITICAL'],
      },
      'factors': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'category': {'type': 'string'},
            'description': {'type': 'string'},
            'weight': {'type': 'number'},
          },
          'required': ['category', 'description', 'weight'],
        },
      },
      'recommendation': {'type': 'string'},
    },
    'required': ['riskIndex', 'riskLevel', 'factors', 'recommendation'],
  };

  /// Simple geohash approximation (not a full geohash, but sufficient for caching).
  String _simpleGeohash(double lat, double lng, {int precision = 6}) {
    final latStr = lat.toStringAsFixed(precision ~/ 2);
    final lngStr = lng.toStringAsFixed(precision ~/ 2);
    return '$latStr,$lngStr';
  }
}
