import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_theme.dart';
import '../../application/providers.dart';
import '../../domain/models/speaking_exercise.dart';
import '../../domain/models/speaking_scenario.dart';
import '../widgets/phrase_card.dart';

/// Passive listen — phrase auto-plays once on entry, learner can replay,
/// then taps the big "Next" button to move on.
///
/// No mic, no scoring — this exercise is about calibrating the ear.
class ListenExerciseWidget extends ConsumerStatefulWidget {
  final ListenExercise exercise;
  final FalouCefr cefr;
  final VoidCallback onDone;

  const ListenExerciseWidget({
    super.key,
    required this.exercise,
    required this.cefr,
    required this.onDone,
  });

  @override
  ConsumerState<ListenExerciseWidget> createState() =>
      _ListenExerciseWidgetState();
}

class _ListenExerciseWidgetState extends ConsumerState<ListenExerciseWidget> {
  bool _autoplayed = false;

  @override
  void initState() {
    super.initState();
    // Defer one frame so the parent Scaffold is mounted before TTS fires.
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoplay());
  }

  Future<void> _autoplay() async {
    if (!mounted || _autoplayed) return;
    _autoplayed = true;
    await _play();
  }

  Future<void> _play() async {
    final coord = ref.read(falouSpeechCoordinatorProvider);
    await coord.playPhrase(widget.exercise.phrase.l2Text, cefr: widget.cefr);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Listen',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.violet,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
        ),
        const SizedBox(height: 20),
        PhraseCard(
          phrase: widget.exercise.phrase,
          onPlay: _play,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.violet,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: widget.onDone,
            child: const Text(
              'Next',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
