
import 'package:flutter_test/flutter_test.dart';
import 'package:peekaboo_mvp/reading/reader_models.dart';

void main() {
  test('paginates plain text into stable word tokens', () {
    final doc = BookDocument.fromPlainText(id: 'demo', title: 'Demo', author: 'A', text: 'one two three four five', wordsPerPage: 2);
    expect(doc.pages.length, 3);
    expect(doc.pages[1].tokens.first.index, 2);
  });

  test('reader settings clamp to child-safe readable ranges', () {
    const settings = ReaderSettings();
    expect(settings.copyWith(fontSize: 8).fontSize, 18);
    expect(settings.copyWith(lineSpacing: 5).lineSpacing, 2.2);
  });
}
