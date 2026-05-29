
import 'package:flutter/foundation.dart';

enum EinkRefreshMode { full, partial, antiGhosting }

abstract interface class EinkRefreshDriver {
  Future<void> refresh(EinkRefreshMode mode, {String? reason});
}

class NoopEinkRefreshDriver implements EinkRefreshDriver {
  final List<String> calls = <String>[];

  @override
  Future<void> refresh(EinkRefreshMode mode, {String? reason}) async {
    calls.add('${mode.name}:${reason ?? ''}');
    debugPrint('EInk refresh placeholder -> ${mode.name} ${reason ?? ''}');
  }
}

class EinkRefreshController {
  EinkRefreshController({EinkRefreshDriver? driver}) : _driver = driver ?? NoopEinkRefreshDriver();

  final EinkRefreshDriver _driver;
  int _partialCount = 0;

  Future<void> onPageTurn() async {
    _partialCount = 0;
    await _driver.refresh(EinkRefreshMode.full, reason: 'page-turn');
  }

  Future<void> onWordHighlight() async {
    _partialCount++;
    if (_partialCount >= 20) {
      _partialCount = 0;
      await _driver.refresh(EinkRefreshMode.antiGhosting, reason: 'highlight-anti-ghosting');
    } else {
      await _driver.refresh(EinkRefreshMode.partial, reason: 'word-highlight');
    }
  }

  Future<void> onRest() => _driver.refresh(EinkRefreshMode.antiGhosting, reason: 'resting-cleanup');
}
