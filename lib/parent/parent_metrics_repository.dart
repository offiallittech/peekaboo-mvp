
import '../reading/reader_models.dart';

class ParentMetricsRepository {
  const ParentMetricsRepository();

  Future<ReadingSessionMetrics> loadDemoMetrics() async {
    return const ReadingSessionMetrics(
      durationSeconds: 842,
      wordsRead: 186,
      difficultWords: ['silver', 'garden', 'whispered'],
      pronunciationAccuracy: .82,
      readingStreak: 4,
    );
  }
}
