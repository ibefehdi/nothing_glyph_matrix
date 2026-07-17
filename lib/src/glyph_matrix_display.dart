import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'glyph_matrix.dart';
import 'rest_time_format.dart';

/// Priority display helper for the Glyph Matrix.
///
/// Priority: celebration > peek > rest > progress > idle image > clear.
///
/// Call [attach] once (e.g. from your app bootstrap) so lifecycle pause/resume
/// clears and restores the matrix. Call [detach] when done.
class GlyphMatrixDisplay with WidgetsBindingObserver {
  GlyphMatrixDisplay({GlyphMatrix? matrix}) : _matrix = matrix ?? GlyphMatrix();

  final GlyphMatrix _matrix;

  bool enabled = true;
  bool supported = false;

  String? _peekText;
  Timer? _peekTimer;

  int? _restSeconds;

  double? _progress;

  String? _celebrationText;
  Timer? _celebrationTimer;

  bool _postClear = false;

  Uint8List? _idleImage;

  Future<void> _chain = Future<void>.value();
  int _generation = 0;
  bool _attached = false;

  bool get _canDisplay => enabled && supported;

  GlyphMatrix get matrix => _matrix;

  Future<void> initialize() async {
    supported = await _matrix.isSupported();
    if (_canDisplay) await refresh();
  }

  void attach() {
    if (_attached) return;
    WidgetsBinding.instance.addObserver(this);
    _attached = true;
  }

  void detach() {
    if (!_attached) return;
    WidgetsBinding.instance.removeObserver(this);
    _attached = false;
    _peekTimer?.cancel();
    _celebrationTimer?.cancel();
    unawaited(_clearNow());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        refresh();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        unawaited(_clearNow());
      case AppLifecycleState.inactive:
        break;
    }
  }

  Future<void> setEnabled(bool value) async {
    if (value == enabled) return;
    enabled = value;
    if (value) {
      await refresh();
    } else {
      _resetAll();
      await _clearNow();
    }
  }

  /// Cancels every transient layer (peek, rest, celebration) and the
  /// progress ring. The single reset used by disable and session teardown.
  void _resetAll() {
    _resetTransient();
    _progress = null;
    _postClear = false;
  }

  /// Invalidates pending frames and enqueues the clear on the serialized
  /// [_chain], so an in-flight [_apply] cannot complete a frame after (and
  /// on top of) the clear.
  Future<void> _clearNow() {
    _invalidate();
    _chain = _chain.catchError((_) {}).then((_) => _matrix.clear());
    return _chain;
  }

  Future<void> setIdleImage(Uint8List? bytes) {
    _idleImage = bytes;
    return refresh();
  }

  Future<void> showPeek(
    String text, {
    Duration duration = const Duration(milliseconds: 500),
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return refresh();

    _peekTimer?.cancel();
    _peekText = trimmed;
    _peekTimer = Timer(duration, () {
      _peekText = null;
      refresh();
    });
    return refresh();
  }

  void cancelPeek() {
    _peekTimer?.cancel();
    _peekTimer = null;
    _peekText = null;
  }

  Future<void> showSeconds(int seconds) {
    _restSeconds = seconds;
    return refresh();
  }

  Future<void> clearRest() {
    _restSeconds = null;
    return refresh();
  }

  Future<void> setProgress(double? fraction) {
    _progress = fraction?.clamp(0.0, 1.0);
    if (_progress != null) _postClear = false;
    return refresh();
  }

  Future<void> celebrate({
    required bool hasPr,
    String prText = 'PR',
    String doneText = 'DONE',
  }) {
    cancelPeek();
    _restSeconds = null;
    _progress = null;
    _celebrationTimer?.cancel();
    _celebrationText = hasPr ? prText : doneText;
    _postClear = true;
    final hold = Duration(milliseconds: hasPr ? 1200 : 1000);
    _celebrationTimer = Timer(hold, () {
      _celebrationText = null;
      refresh();
    });
    return refresh();
  }

  /// Resets every session-related layer and repaints idle/clear. This is the
  /// single teardown entry point (formerly duplicated as `endCelebration`).
  Future<void> clearSession() {
    _resetAll();
    return refresh();
  }

  Future<void> refresh() {
    final generation = ++_generation;
    _chain = _chain.catchError((_) {}).then((_) => _apply(generation));
    return _chain;
  }

  void _resetTransient() {
    cancelPeek();
    _restSeconds = null;
    _celebrationTimer?.cancel();
    _celebrationTimer = null;
    _celebrationText = null;
  }

  void _invalidate() => _generation++;

  Future<void> _apply(int generation) async {
    if (generation != _generation || !_canDisplay) return;

    final celebration = _celebrationText;
    if (celebration != null) {
      await _matrix.showText(celebration);
      return;
    }

    final peek = _peekText;
    if (peek != null) {
      await _matrix.showText(peek);
      return;
    }

    final rest = _restSeconds;
    if (rest != null && rest > 0) {
      await _matrix.showText(formatRestCountdown(rest, compact: true));
      return;
    }

    final progress = _progress;
    if (progress != null) {
      await _matrix.showProgress(progress);
      return;
    }

    if (_postClear) {
      await _matrix.clear();
      return;
    }

    final idle = _idleImage;
    if (idle != null && idle.isNotEmpty) {
      await _matrix.showImage(idle);
      return;
    }

    await _matrix.clear();
  }
}
