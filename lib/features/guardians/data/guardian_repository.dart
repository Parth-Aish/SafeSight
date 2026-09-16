import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/models/guardian.dart';

class GuardianRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  GuardianRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _guardians(String uid) =>
      _firestore.collection('users').doc(uid).collection('guardians');

  Stream<List<Guardian>> watchGuardians() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Stream.value(const []);
    }
    return _guardians(uid).snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => Guardian.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> pairByEmail(String email) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('You must be signed in to pair a guardian.');
    }
    final normalizedEmail = email.trim().toLowerCase();
    if (!normalizedEmail.contains('@')) {
      throw const FormatException('Enter a valid guardian email.');
    }

    final pairId = normalizedEmail.replaceAll(RegExp(r'[^a-z0-9]'), '_');
    await _guardians(uid).doc(pairId).set(
          Guardian(id: pairId, email: normalizedEmail).toMap(),
          SetOptions(merge: true),
        );
  }

  Future<void> remove(String guardianId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _guardians(uid).doc(guardianId).delete();
  }
}
