
import 'package:flutter/services.dart' show rootBundle;

import 'reader_models.dart';

class BookRepository {
  Future<BookDocument> loadSampleBook() async {
    final text = await rootBundle.loadString('assets/books/sample_story.txt');
    return BookDocument.fromPlainText(id: 'sample-moon-garden', title: 'Milo and the Moon Garden', author: 'Peekaboo Demo', text: text);
  }
}
