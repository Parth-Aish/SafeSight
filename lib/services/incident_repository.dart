import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

final incidentRepositoryProvider = Provider<IncidentRepository>(
  (ref) => IncidentRepository(),
);

class CommunityIncident {
  final String id;
  final String type;
  final double latitude;
  final double longitude;
  final DateTime? reportedAt;

  const CommunityIncident({
    required this.id,
    required this.type,
    required this.latitude,
    required this.longitude,
    this.reportedAt,
  });

  LatLng get position => LatLng(latitude, longitude);

  factory CommunityIncident.fromDocument(
      QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    final timestamp = data['timestamp'];
    return CommunityIncident(
      id: document.id,
      type: data['type'] as String? ?? 'Suspicious Activity',
      latitude: (data['lat'] as num?)?.toDouble() ?? 0,
      longitude: (data['lng'] as num?)?.toDouble() ?? 0,
      reportedAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}

class IncidentRepository {
  final FirebaseFirestore _firestore;

  IncidentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<CommunityIncident>> watchIncidents() {
    return _firestore.collection('incidents').snapshots().map((snapshot) {
      final incidents = snapshot.docs
          .map(CommunityIncident.fromDocument)
          .where((incident) =>
              incident.latitude != 0 && incident.longitude != 0)
          .toList();
      incidents.sort((a, b) {
        if (a.reportedAt == null || b.reportedAt == null) return 0;
        return b.reportedAt!.compareTo(a.reportedAt!);
      });
      return incidents;
    });
  }

  Future<void> report({required LatLng position, required String type}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in to report an incident.');
    await _firestore.collection('incidents').add({
      'lat': position.latitude,
      'lng': position.longitude,
      'type': type,
      'userId': user.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}