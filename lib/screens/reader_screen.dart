
import 'package:flutter/material.dart';

import '../aloud/audio_recorder_service.dart';
import '../aloud/read_aloud_controller.dart';
import '../eink/eink_refresh.dart';
import '../reading/reader_models.dart';
import '../supabase/peekaboo_supabase.dart';
import '../theme/eink_theme.dart';
import '../vocabulary/vocabulary_models.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.book, required this.supabase, required this.einkRefresh});
  final BookDocument book;
  final PeekabooSupabase supabase;
  final EinkRefreshController einkRefresh;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  int _pageIndex = 0;
  ReaderSettings _settings = const ReaderSettings();
  late List<WordToken> _tokens = widget.book.pages.first.tokens;
  late final ReadAloudController _aloud = ReadAloudController(supabase: widget.supabase, einkRefresh: widget.einkRefresh);
  final _demoTranscript = TextEditingController(text: 'Milo read under the moon and found a tiny silver seed');
  final _recorder = AudioRecorderService();
  bool _isListening = false;

  BookPage get _page => widget.book.pages[_pageIndex];

  Future<void> _turn(int delta) async {
    final next = (_pageIndex + delta).clamp(0, widget.book.pages.length - 1);
    if (next == _pageIndex) return;
    setState(() {
      _pageIndex = next;
      _tokens = widget.book.pages[_pageIndex].tokens;
    });
    await widget.einkRefresh.onPageTurn();
    await widget.supabase.saveReadingPosition(ReadingPosition(bookId: widget.book.id, pageIndex: _pageIndex, wordIndex: _tokens.first.index));
  }

  Future<void> _scoreDemo() async {
    final scored = await _aloud.scoreVisibleWords(page: _page, transcript: _demoTranscript.text);
    if (!mounted) return;
    setState(() => _tokens = scored);
  }

  Future<void> _toggleListen() async {
    if (!_isListening) {
      await _recorder.start();
      if (!mounted) return;
      setState(() => _isListening = true);
      return;
    }
    final audioBytes = await _recorder.stopAndReadBytes();
    final transcript = await widget.supabase.transcribeWhisperDemo(audioBytes: audioBytes);
    _demoTranscript.text = transcript;
    if (!mounted) return;
    setState(() => _isListening = false);
    await _scoreDemo();
  }

  Future<void> _showWord(String rawWord) async {
    final word = rawWord.replaceAll(RegExp(r"[^A-Za-z0-9']"), '');
    final entry = await widget.supabase.lookupWord(word);
    if (!mounted) return;
    showDialog<void>(context: context, builder: (_) => _VocabularyDialog(entry: entry, onSave: () => widget.supabase.saveVocabularyLookup(entry)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.book.title), actions: [
        IconButton(onPressed: () => setState(() => _settings = _settings.copyWith(fontSize: _settings.fontSize - 2)), icon: const Icon(Icons.text_decrease)),
        IconButton(onPressed: () => setState(() => _settings = _settings.copyWith(fontSize: _settings.fontSize + 2)), icon: const Icon(Icons.text_increase)),
        IconButton(onPressed: () => setState(() => _settings = _settings.copyWith(lineSpacing: _settings.lineSpacing + .1)), icon: const Icon(Icons.format_line_spacing)),
      ]),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            child: Column(children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(border: Border.all(color: EinkTheme.rule), borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 10,
                        children: _tokens.map((token) => InkWell(
                          onTap: () => _showWord(token.text),
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: _qualityColor(token.quality), borderRadius: BorderRadius.circular(6)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                              child: Text(token.text, style: TextStyle(fontSize: _settings.fontSize, height: _settings.lineSpacing, color: EinkTheme.ink)),
                            ),
                          ),
                        )).toList(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(children: [
                OutlinedButton.icon(onPressed: () => _turn(-1), icon: const Icon(Icons.chevron_left), label: const Text('Previous')),
                Expanded(child: Center(child: Text('Page ${_pageIndex + 1} of ${widget.book.pages.length}'))),
                OutlinedButton.icon(onPressed: () => _turn(1), icon: const Icon(Icons.chevron_right), label: const Text('Next')),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: _demoTranscript,
                decoration: const InputDecoration(labelText: 'Read-aloud demo transcript / Whisper output', border: OutlineInputBorder()),
                minLines: 1,
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Row(children: [
                FilledButton.icon(onPressed: _toggleListen, icon: Icon(_isListening ? Icons.stop_circle_outlined : Icons.mic_none), label: Text(_isListening ? 'Stop + score with Whisper' : 'Listen with Whisper')),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: _scoreDemo, child: const Text('Score typed demo')),
                const SizedBox(width: 12),
                const Expanded(child: Text('Green = read clearly, yellow = almost/hesitation, red = practice later.')),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Color _qualityColor(ReadingQuality quality) => switch (quality) {
    ReadingQuality.correct => EinkTheme.correct,
    ReadingQuality.hesitation => EinkTheme.partial,
    ReadingQuality.incorrect => EinkTheme.needsPractice,
    ReadingQuality.unread => Colors.transparent,
  };
}

class _VocabularyDialog extends StatelessWidget {
  const _VocabularyDialog({required this.entry, required this.onSave});
  final VocabularyEntry entry;
  final Future<void> Function() onSave;
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(entry.word),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(entry.meaning),
        const SizedBox(height: 12),
        Text('Say it: ${entry.pronunciation}'),
        if (entry.exampleSentence != null) ...[const SizedBox(height: 12), Text(entry.exampleSentence!)],
        const SizedBox(height: 12),
        Container(height: 96, alignment: Alignment.center, decoration: BoxDecoration(border: Border.all(color: EinkTheme.rule)), child: const Text('Image placeholder')),
      ]),
      actions: [
        TextButton(onPressed: () async { await onSave(); if (context.mounted) Navigator.of(context).pop(); }, child: const Text('Save word')),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back to story')),
      ],
    );
  }
}
