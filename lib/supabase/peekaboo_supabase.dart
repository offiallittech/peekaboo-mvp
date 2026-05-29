
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../reading/reader_models.dart';
import '../vocabulary/vocabulary_models.dart';

class PeekabooSupabase {
  PeekabooSupabase({String? url, String? anonKey, http.Client? client})
      : url = url ?? const String.fromEnvironment('SUPABASE_URL'),
        anonKey = anonKey ?? const String.fromEnvironment('SUPABASE_ANON_KEY'),
        _client = client ?? http.Client();

  final String url;
  final String anonKey;
  final http.Client _client;

  bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  Future<String> transcribeWhisperDemo({required List<int> audioBytes}) async {
    if (!isConfigured || audioBytes.isEmpty) return 'milo read under the moon and found a tiny silver seed';
    final request = http.MultipartRequest('POST', Uri.parse('$url/functions/v1/whisper-stt'))
      ..headers['Authorization'] = 'Bearer $anonKey'
      ..files.add(http.MultipartFile.fromBytes('audio', audioBytes, filename: 'reading.m4a'));
    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode >= 400) throw StateError(body);
    return (jsonDecode(body) as Map<String, dynamic>)['transcript']?.toString() ?? '';
  }

  Future<List<Map<String, dynamic>>> scorePronunciation({required String visibleText, required String transcript}) async {
    if (!isConfigured) return const [];
    final response = await _client.post(
      Uri.parse('$url/functions/v1/pronunciation-score'),
      headers: {'Authorization': 'Bearer $anonKey', 'Content-Type': 'application/json'},
      body: jsonEncode({'expected_text': visibleText, 'spoken_text': transcript}),
    );
    if (response.statusCode >= 400) return const [];
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return (decoded['word_attempts'] as List? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<VocabularyEntry> lookupWord(String word) async {
    if (!isConfigured) {
      return VocabularyEntry(
        word: word,
        meaning: 'A friendly word from this story. Ask: what is happening around "$word"?',
        pronunciation: '/${word.toLowerCase()}/',
        exampleSentence: 'Can you use "$word" in your own sentence?',
      );
    }
    final response = await _client.post(
      Uri.parse('$url/functions/v1/vocabulary-explanation'),
      headers: {'Authorization': 'Bearer $anonKey', 'Content-Type': 'application/json'},
      body: jsonEncode({'word': word, 'child_age': 7}),
    );
    if (response.statusCode >= 400) throw StateError(response.body);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return VocabularyEntry(
      word: data['word']?.toString() ?? word,
      meaning: data['meaning']?.toString() ?? 'A word from the story.',
      pronunciation: data['pronunciation']?.toString() ?? '/$word/',
      exampleSentence: data['example_sentence']?.toString(),
      imageUrl: data['image_url']?.toString(),
    );
  }

  Future<void> saveVocabularyLookup(VocabularyEntry entry) async {
    if (!isConfigured) return;
    await _secureAction('save_vocabulary_lookup', {
      'word': entry.word,
      'meaning': entry.meaning,
      'pronunciation': entry.pronunciation,
      'example_sentence': entry.exampleSentence,
    });
  }

  Future<void> uploadEbookMetadata({required String title, required String storagePath, required String format}) async {
    if (!isConfigured) return;
    await _secureAction('register_book_upload', {'title': title, 'storage_path': storagePath, 'format': format});
  }

  Future<void> saveReadingPosition(ReadingPosition position) async {
    if (!isConfigured) return;
    await _secureAction('save_position', position.toJson());
  }

  Future<ReadingSessionMetrics> loadParentSummary() async {
    if (!isConfigured) {
      return const ReadingSessionMetrics(durationSeconds: 842, wordsRead: 186, difficultWords: ['silver', 'garden', 'whispered'], pronunciationAccuracy: .82, readingStreak: 4);
    }
    final response = await _client.post(Uri.parse('$url/functions/v1/parent-summary'), headers: {'Authorization': 'Bearer $anonKey', 'Content-Type': 'application/json'}, body: '{}');
    if (response.statusCode >= 400) throw StateError(response.body);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return ReadingSessionMetrics(
      durationSeconds: (data['duration_seconds'] as num? ?? 0).round(),
      wordsRead: (data['words_read'] as num? ?? 0).round(),
      difficultWords: (data['difficult_words'] as List? ?? const []).map((e) => e.toString()).toList(),
      pronunciationAccuracy: (data['pronunciation_accuracy'] as num? ?? 0).toDouble(),
      readingStreak: (data['reading_streak'] as num? ?? 0).round(),
    );
  }

  Future<void> _secureAction(String action, Map<String, dynamic> payload) async {
    await _client.post(
      Uri.parse('$url/functions/v1/secure-api'),
      headers: {'Authorization': 'Bearer $anonKey', 'Content-Type': 'application/json'},
      body: jsonEncode({'action': action, 'payload': payload}),
    );
  }
}
