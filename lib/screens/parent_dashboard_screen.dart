import 'package:flutter/material.dart';

import '../reading/reader_models.dart';
import '../supabase/peekaboo_supabase.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  late final Future<ReadingSessionMetrics> _metrics = PeekabooSupabase().loadParentSummary();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parent progress')),
      body: FutureBuilder<ReadingSessionMetrics>(
        future: _metrics,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: Text('Gathering calm progress notes…'));
          final metrics = snapshot.data!;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: GridView.count(
                padding: const EdgeInsets.all(28),
                crossAxisCount: MediaQuery.of(context).size.width > 700 ? 2 : 1,
                childAspectRatio: 2.8,
                crossAxisSpacing: 18,
                mainAxisSpacing: 18,
                children: [
                  _MetricCard(label: 'Session duration', value: '${(metrics.durationSeconds / 60).round()} min'),
                  _MetricCard(label: 'Words read', value: '${metrics.wordsRead}'),
                  _MetricCard(label: 'Pronunciation accuracy', value: '${(metrics.pronunciationAccuracy * 100).round()}%'),
                  _MetricCard(label: 'Reading streak', value: '${metrics.readingStreak} days'),
                  _MetricCard(label: 'Difficult words', value: metrics.difficultWords.join(', ')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade500), borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ]),
      ),
    );
  }
}
