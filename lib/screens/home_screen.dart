
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../eink/eink_refresh.dart';
import '../reading/book_repository.dart';
import '../reading/ebook_import_service.dart';
import '../reading/reader_models.dart';
import '../supabase/peekaboo_supabase.dart';
import 'parent_dashboard_screen.dart';
import 'reader_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<BookDocument> _book;
  final _supabase = PeekabooSupabase();
  final _eink = EinkRefreshController();
  final _importer = EbookImportService();

  @override
  void initState() {
    super.initState();
    _book = BookRepository().loadSampleBook();
  }

  Future<void> _importEpub() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['epub', 'pdf'], withData: true);
    final file = picked?.files.single;
    if (file == null || file.bytes == null) return;
    final extension = (file.extension ?? '').toLowerCase();
    final imported = extension == 'epub'
        ? await _importer.openEpub(file.bytes!, bookId: 'local-${DateTime.now().millisecondsSinceEpoch}')
        : await _importer.openPdfPlaceholder(file.bytes!, bookId: 'local-${DateTime.now().millisecondsSinceEpoch}', title: file.name);
    await _supabase.uploadEbookMetadata(title: imported.title, storagePath: 'ebooks/${file.name}', format: extension);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReaderScreen(book: imported, supabase: _supabase, einkRefresh: _eink)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Peekaboo'), actions: [
        TextButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ParentDashboardScreen())),
          icon: const Icon(Icons.insights_outlined),
          label: const Text('Parent'),
        )
      ]),
      body: FutureBuilder<BookDocument>(
        future: _book,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: Text('Opening a calm reading space…'));
          final book = snapshot.data!;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Today’s book', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade500), borderRadius: BorderRadius.circular(18)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(24),
                      title: Text(book.title, style: Theme.of(context).textTheme.headlineMedium),
                      subtitle: Text('${book.author}\nEPUB/PDF upload path is wired through Supabase Storage; this demo opens the bundled story.'),
                      trailing: const Icon(Icons.menu_book_outlined, size: 44),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReaderScreen(book: book, supabase: _supabase, einkRefresh: _eink))),
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(onPressed: _importEpub, icon: const Icon(Icons.upload_file), label: const Text('Import EPUB/PDF')),
                  const SizedBox(height: 24),
                  const Text('No ads • no web browsing • parent-controlled account • grayscale-first for E Ink tablets'),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}
