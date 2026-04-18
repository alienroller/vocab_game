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

    test('apostrophes are preserved (contractions matter)', () {
      // "im" vs "i'm" should differ because the normalizer keeps the apostrophe.
      expect(scorer.score("i'm fine", "im fine") < 1.0, isTrue);
    });

    test('single-char typo still passes threshold', () {
      final s = scorer.score('i wood like a coffee', 'i would like a coffee');
      expect(s, greaterThan(PronunciationScorer.defaultThreshold));
    });

    test('completely different text fails threshold', () {
      final s = scorer.score('the cat sat on the mat',
          'would you like another cup of coffee please');
      expect(s, lessThan(PronunciationScorer.defaultThreshold));
    });

    test('empty transcription scores 0.0', () {
      expect(scorer.score('', 'hello world'), 0.0);
    });

    test('empty target scores 0.0', () {
      expect(scorer.score('hello', ''), 0.0);
    });

    test('missing filler word still passes', () {
      // Drops "please" — Jaccard penalty is small, character ratio OK.
      final s = scorer.score('i would like a coffee', 'i would like a coffee please');
      expect(s, greaterThan(PronunciationScorer.defaultThreshold));
    });

    test('word order swap partially penalized, still passable', () {
      final s = scorer.score('coffee a like would i', 'i would like a coffee');
      // Jaccard is 1.0 (same words), Levenshtein is poor — blend should still pass.
      expect(s, greaterThan(0.5));
    });

    test('passes() convenience matches default threshold', () {
      expect(scorer.passes('hello world', 'hello world'), isTrue);
      expect(scorer.passes('', 'hello world'), isFalse);
    });
  });
}
