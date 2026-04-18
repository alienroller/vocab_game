import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/seed/falou_scenarios.dart';
import '../data/speech/falou_speech_coordinator.dart';
import '../domain/models/speaking_scenario.dart';

/// All scenarios available in v1 (in-memory seed).
final falouScenariosProvider = Provider<List<SpeakingScenario>>((ref) {
  return FalouScenarios.all;
});

/// Lookup one scenario by id. Returns null if unknown.
final falouScenarioByIdProvider =
    Provider.family<SpeakingScenario?, String>((ref, id) {
  return FalouScenarios.byId(id);
});

/// Shared mic + TTS bridge for all exercise widgets. Kept as a plain
/// [Provider] because it's a stateless facade over the two singletons.
final falouSpeechCoordinatorProvider = Provider<FalouSpeechCoordinator>((ref) {
  return FalouSpeechCoordinator();
});
