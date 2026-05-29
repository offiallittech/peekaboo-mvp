
import 'dart:typed_data';

import 'package:epubx/epubx.dart';

import 'reader_models.dart';

class EbookImportService {
  Future<BookDocument> openEpub(Uint8List bytes, {required String bookId}) async {
    final epub = await EpubReader.readBook(bytes);
    final chapters = epub.Chapters?.map(_chapterText).where((s) => s.trim().isNotEmpty).join('\n\n') ?? '';
    final title = epub.Title?.trim().isNotEmpty == true ? epub.Title!.trim() : 'Untitled EPUB';
    final author = epub.Author?.trim().isNotEmpty == true ? epub.Author!.trim() : 'Unknown author';
    return BookDocument.fromPlainText(id: bookId, title: title, author: author, text: chapters, wordsPerPage: 90);
  }

  Future<BookDocument> openPdfPlaceholder(Uint8List bytes, {required String bookId, required String title}) async {
    // MVP placeholder: Android UI and Supabase metadata path are ready; production can
    // swap this for MuPDF/native PDF text extraction without changing ReaderScreen.
    return BookDocument.fromPlainText(
      id: bookId,
      title: title,
      author: 'PDF import',
      text: 'PDF support is available as a viewer/import placeholder in this MVP. EPUB is the primary reading format.',
    );
  }

  String _chapterText(EpubChapter chapter) {
    final own = chapter.HtmlContent?.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll('&nbsp;', ' ') ?? '';
    final nested = chapter.SubChapters?.map(_chapterText).join('\n') ?? '';
    return '$own\n$nested';
  }
}
