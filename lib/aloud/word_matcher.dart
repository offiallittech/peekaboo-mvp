
import 'dart:math' as math;

import '../reading/reader_models.dart';

class WordAttemptResult {
  const WordAttemptResult({required this.expected, required this.spoken, required this.quality, required this.score});
  final String expected;
  final String spoken;
  final ReadingQuality quality;
  final double score;
}

class WordMatcher {
  List<WordAttemptResult> match({required List<WordToken> visibleTokens, required String transcript}) {
    final spokenWords = _tokenize(transcript);
    var spokenCursor = 0;
    final results = <WordAttemptResult>[];
    for (final token in visibleTokens) {
      final expected = _clean(token.text);
      if (expected.isEmpty) continue;
      if (spokenCursor >= spokenWords.length) {
        results.add(WordAttemptResult(expected: expected, spoken: '', quality: ReadingQuality.incorrect, score: 0));
        continue;
      }
      final spoken = spokenWords[spokenCursor];
      final score = similarity(expected, spoken);
      if (score >= 0.88) {
        spokenCursor++;
        results.add(WordAttemptResult(expected: expected, spoken: spoken, quality: ReadingQuality.correct, score: score));
      } else if (score >= 0.58 || _nextWordMatches(spokenWords, spokenCursor, expected)) {
        spokenCursor++;
        results.add(WordAttemptResult(expected: expected, spoken: spoken, quality: ReadingQuality.hesitation, score: score));
      } else {
        results.add(WordAttemptResult(expected: expected, spoken: spoken, quality: ReadingQuality.incorrect, score: score));
      }
    }
    return results;
  }

  double accuracy(List<WordAttemptResult> results) {
    if (results.isEmpty) return 0;
    final points = results.fold<double>(0, (sum, r) => sum + switch (r.quality) {
          ReadingQuality.correct => 1,
          ReadingQuality.hesitation => .55,
          ReadingQuality.incorrect => 0,
          ReadingQuality.unread => 0,
        });
    return points / results.length;
  }

  bool _nextWordMatches(List<String> spokenWords, int cursor, String expected) {
    if (cursor + 1 >= spokenWords.length) return false;
    return similarity(expected, spokenWords[cursor + 1]) >= 0.88;
  }

  List<String> _tokenize(String text) => text.split(RegExp(r'\s+')).map(_clean).where((w) => w.isNotEmpty).toList();

  String _clean(String input) => input.toLowerCase().replaceAll(RegExp(r"[^a-z0-9']"), '');

  double similarity(String a, String b) {
    if (a == b) return 1;
    if (a.isEmpty || b.isEmpty) return 0;
    final distance = _levenshtein(a, b);
    return 1 - distance / math.max(a.length, b.length);
  }

  int _levenshtein(String a, String b) {
    final prev = List<int>.generate(b.length + 1, (i) => i);
    final curr = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        curr[j] = math.min(math.min(curr[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
      }
      for (var j = 0; j <= b.length; j++) {
        prev[j] = curr[j];
      }
    }
    return prev[b.length];
  }
}
