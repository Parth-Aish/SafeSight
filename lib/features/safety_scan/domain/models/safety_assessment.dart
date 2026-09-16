import 'package:flutter/material.dart';

import 'package:safesight/src/features/safety_scan/data/datasources/gemini_risk_datasource.dart';

enum SafetyLevel { safe, moderate, alert }

class SafetyAssessment {
  final SafetyLevel level;
  final double confidenceScore;
  final String summary;
  final String actionAdvice;
  final bool hasRecentIncident;
  final int newsCount;
  final int communityIncidentCount;
  final DateTime assessedAt;
  final bool isStale;

  /// Individual risk factors contributing to the assessment.
  final List<RiskFactor> factors;

  /// How much data was available to make this assessment (0-1).
  final double dataConfidence;

  /// AI model used for assessment, if any (e.g., "gemini-1.5-flash").
  final String? aiModelVersion;

  /// Age of the oldest data point used in this assessment.
  final DateTime? dataFreshness;

  const SafetyAssessment({
    required this.level,
    required this.confidenceScore,
    required this.summary,
    required this.actionAdvice,
    required this.hasRecentIncident,
    required this.newsCount,
    required this.communityIncidentCount,
    required this.assessedAt,
    this.isStale = false,
    this.factors = const [],
    this.dataConfidence = 0.5,
    this.aiModelVersion,
    this.dataFreshness,
  });

  double get score => switch (level) {
        SafetyLevel.safe => 0.85,
        SafetyLevel.moderate => 0.55,
        SafetyLevel.alert => 0.2,
      };

  String get status => switch (level) {
        SafetyLevel.safe => 'SAFE',
        SafetyLevel.moderate => 'MODERATE RISK',
        SafetyLevel.alert => 'ALERT',
      };

  Color get color => switch (level) {
        SafetyLevel.safe => const Color(0xFF34D399),
        SafetyLevel.moderate => const Color(0xFFEAB308),
        SafetyLevel.alert => const Color(0xFFF43F5E),
      };

  /// Whether this assessment was enhanced by AI analysis.
  bool get isAiEnhanced => aiModelVersion != null;

  factory SafetyAssessment.safe({
    int newsCount = 0,
    int communityIncidentCount = 0,
    String summary = 'No verified recent safety incidents were found nearby.',
    List<RiskFactor> factors = const [],
    String? aiModelVersion,
  }) {
    return SafetyAssessment(
      level: SafetyLevel.safe,
      confidenceScore: 0.85,
      summary: summary,
      actionAdvice:
          'Stay aware of your surroundings and keep a trusted contact available.',
      hasRecentIncident: false,
      newsCount: newsCount,
      communityIncidentCount: communityIncidentCount,
      assessedAt: DateTime.now(),
      factors: factors,
      dataConfidence: factors.isEmpty ? 0.5 : 0.8,
      aiModelVersion: aiModelVersion,
    );
  }
}

