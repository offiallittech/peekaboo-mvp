
import '../eink/eink_refresh.dart';
import '../reading/reader_models.dart';
import '../supabase/peekaboo_supabase.dart';
import 'word_matcher.dart';

class ReadAloudController {
  ReadAloudController({required this.supabase, required this.einkRefresh, WordMatcher? matcher}) : matcher = matcher ?? WordMatcher();
  final PeekabooSupabase supabase;
  final EinkRefreshController einkRefresh;
  final WordMatcher matcher;

  Future<List<WordToken>> scoreVisibleWords({required BookPage page, required String transcript}) async {
    final remote = await supabase.scorePronunciation(visibleText: page.plainText, transcript: transcript);
    final scored = remote.isNotEmpty
        ? remote
        : matcher.match(visibleTokens: page.tokens, transcript: transcript)
            .map((r) => {'expected': r.expected, 'quality': r.quality.name, 'score': r.score})
            .toList();
    final byExpected = <String, String>{for (final item in scored) (item['expected'] ?? '').toString().toLowerCase(): (item['quality'] ?? 'unread').toString()};
    final updated = page.tokens.map((token) {
      final q = byExpected[token.text.toLowerCase().replaceAll(RegExp(r"[^a-z0-9']"), '')] ?? 'unread';
      return token.copyWith(quality: switch (q) {
        'correct' => ReadingQuality.correct,
        'hesitation' || 'partial' => ReadingQuality.hesitation,
        'incorrect' || 'skipped' => ReadingQuality.incorrect,
        _ => ReadingQuality.unread,
      });
    }).toList();
    await einkRefresh.onWordHighlight();
    return updated;
  }
}
