
import 'package:flutter_test/flutter_test.dart';
import 'package:peekaboo_mvp/aloud/word_matcher.dart';
import 'package:peekaboo_mvp/reading/reader_models.dart';

void main() {
  test('marks exact read words as correct', () {
    final page = BookDocument.fromPlainText(id: 'b', title: 't', author: 'a', text: 'Milo found moon seeds').pages.first;
    final results = WordMatcher().match(visibleTokens: page.tokens, transcript: 'Milo found moon seeds');
    expect(results.map((r) => r.quality), everyElement(ReadingQuality.correct));
  });

  test('marks near pronunciations as hesitation and skipped words as incorrect', () {
    final page = BookDocument.fromPlainText(id: 'b', title: 't', author: 'a', text: 'silver garden glowed').pages.first;
    final results = WordMatcher().match(visibleTokens: page.tokens, transcript: 'silva glowed');
    expect(results[0].quality, ReadingQuality.hesitation);
    expect(results[1].quality, ReadingQuality.incorrect);
  });
}
