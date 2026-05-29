
import 'dart:math' as math;

enum ReadingQuality { unread, correct, hesitation, incorrect }

class ReaderSettings {
  const ReaderSettings({this.fontSize = 26, this.lineSpacing = 1.45});
  final double fontSize;
  final double lineSpacing;

  ReaderSettings copyWith({double? fontSize, double? lineSpacing}) => ReaderSettings(
        fontSize: (fontSize ?? this.fontSize).clamp(18, 42).toDouble(),
        lineSpacing: (lineSpacing ?? this.lineSpacing).clamp(1.1, 2.2).toDouble(),
      );
}

class WordToken {
  const WordToken({required this.text, required this.index, this.quality = ReadingQuality.unread});
  final String text;
  final int index;
  final ReadingQuality quality;

  WordToken copyWith({ReadingQuality? quality}) => WordToken(text: text, index: index, quality: quality ?? this.quality);
}

class BookPage {
  const BookPage({required this.pageIndex, required this.tokens});
  final int pageIndex;
  final List<WordToken> tokens;
  String get plainText => tokens.map((t) => t.text).join(' ');
}

class BookDocument {
  const BookDocument({required this.id, required this.title, required this.author, required this.pages});
  final String id;
  final String title;
  final String author;
  final List<BookPage> pages;

  static BookDocument fromPlainText({
    required String id,
    required String title,
    required String author,
    required String text,
    int wordsPerPage = 90,
  }) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.trim().isNotEmpty).toList();
    final pages = <BookPage>[];
    for (var start = 0; start < words.length; start += wordsPerPage) {
      final slice = words.sublist(start, math.min(start + wordsPerPage, words.length));
      pages.add(BookPage(
        pageIndex: pages.length,
        tokens: [for (var i = 0; i < slice.length; i++) WordToken(text: slice[i], index: start + i)],
      ));
    }
    return BookDocument(id: id, title: title, author: author, pages: pages);
  }
}

class ReadingPosition {
  const ReadingPosition({required this.bookId, required this.pageIndex, required this.wordIndex});
  final String bookId;
  final int pageIndex;
  final int wordIndex;

  Map<String, dynamic> toJson() => {'book_id': bookId, 'page_index': pageIndex, 'word_index': wordIndex};
}

class ReadingSessionMetrics {
  const ReadingSessionMetrics({
    required this.durationSeconds,
    required this.wordsRead,
    required this.difficultWords,
    required this.pronunciationAccuracy,
    required this.readingStreak,
  });
  final int durationSeconds;
  final int wordsRead;
  final List<String> difficultWords;
  final double pronunciationAccuracy;
  final int readingStreak;
}
