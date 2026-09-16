import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/repositories/safety_repository.dart';
import '../../domain/models/safety_assessment.dart';

final safetyRepositoryProvider =
    Provider<SafetyRepository>((ref) => SafetyRepository());

final safetyScanNotifierProvider =
    AsyncNotifierProvider<SafetyScanNotifier, SafetyAssessment>(
  SafetyScanNotifier.new,
);

class SafetyScanNotifier extends AsyncNotifier<SafetyAssessment> {
  @override
  Future<SafetyAssessment> build() async => SafetyAssessment.safe();

  Future<void> scan({required Position position, required String city}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(safetyRepositoryProvider)
          .assess(position: position, city: city),
    );
  }
}
