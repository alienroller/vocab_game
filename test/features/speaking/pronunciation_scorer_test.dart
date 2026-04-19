import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_game/features/speaking/data/speech/pronunciation_scorer.dart';

void main() {
  const scorer = PronunciationScorer();

  group('PronunciationScorer.score', () {
    test('identical strings score 1.0', () {
      expect(scorer.score('hello world', 'hello world'), closeTo(1.0, 1e-9));
    });

    test('case and trailing whitespace do not matter', () {
      expect(scorer.score('  HELLO world  ', 'hello world'), closeTo(1.0, 1e-9));
    });

    test('punctuation is stripped before comparison', () {
      expect(scorer.score('Hello, world!', 'hello world'), closeTo(1.0, 1e-9));
    });

    test('empty transcription scores 0.0', () {
      expect(scorer.score('', 'hello world'), 0.0);
    });

    test('empty target scores 0.0', () {
      expect(scorer.score('hello', ''), 0.0);
    });
  });

  group('PronunciationScorer.passes', () {
    test('exact match passes', () {
      expect(scorer.passes('what is your name', 'what is your name'), isTrue);
    });

    test('single-char STT typo on a longer word still passes', () {
      // 1-edit in an 8-letter word → ratio 0.875, within the fuzzy-match bar.
      // Short-word typos intentionally don't fuzzy-match (wrong pronunciation
      // in a learning app should not silently count as correct).
      expect(scorer.passes('see you tomarrow', 'see you tomorrow'), isTrue);
    });

    test('dropping one small word still passes (recall floor)', () {
      // STT sometimes drops an auxiliary — recall drops to 0.75 which is the
      // lower bound we accept.
      expect(scorer.passes('what your name', 'what is your name'), isTrue);
    });

    test('adding an extra word fails (precision gate)', () {
      // The "fucking" case from the bug report: recall 1.0, precision 0.80 —
      // must not pass.
      expect(
        scorer.passes('what is your fucking name', 'what is your name'),
        isFalse,
      );
    });

    test('filler words (uh/um) are stripped, do not hurt precision', () {
      expect(
        scorer.passes('what is uh your um name', 'what is your name'),
        isTrue,
      );
    });

    test('trailing extra phrase fails', () {
      expect(
        scorer.passes(
            'what is your name please tell me', 'what is your name'),
        isFalse,
      );
    });

    test('word-order swap fails (sequence aware)', () {
      // A bag-of-words metric would pass this; sequence alignment rejects it.
      expect(
        scorer.passes('coffee a like would i', 'i would like a coffee'),
        isFalse,
      );
    });

    test('completely different text fails', () {
      expect(
        scorer.passes('the cat sat on the mat',
            'would you like another cup of coffee please'),
        isFalse,
      );
    });

    test('empty transcription fails', () {
      expect(scorer.passes('', 'hello world'), isFalse);
    });

    test('empty target fails', () {
      expect(scorer.passes('hello', ''), isFalse);
    });
  });
}
