
class VocabularyEntry {
  const VocabularyEntry({required this.word, required this.meaning, required this.pronunciation, this.exampleSentence, this.imageUrl});
  final String word;
  final String meaning;
  final String pronunciation;
  final String? exampleSentence;
  final String? imageUrl;
}
