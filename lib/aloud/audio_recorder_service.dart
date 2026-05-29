
import 'dart:io';

import 'package:record/record.dart';

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  Future<bool> get hasPermission => _recorder.hasPermission();

  Future<void> start() async {
    if (!await _recorder.hasPermission()) return;
    final path = '${Directory.systemTemp.path}/peekaboo-reading-${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
  }

  Future<List<int>> stopAndReadBytes() async {
    final path = await _recorder.stop();
    if (path == null) return const [];
    return File(path).readAsBytes();
  }

  Future<void> dispose() => _recorder.dispose();
}
