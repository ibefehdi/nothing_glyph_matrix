import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Low-level MethodChannel client for the Nothing Glyph Matrix.
///
/// Safe no-op on non-Android platforms and when the native plugin is missing.
class GlyphMatrix {
  GlyphMatrix({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'nothing_glyph_matrix';

  final MethodChannel _channel;
  bool _registered = false;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> isSupported() async {
    if (!_isAndroid) return false;
    return await _invoke<bool>('isSupported') ?? false;
  }

  /// Binds the native Glyph Matrix service. Idempotent.
  Future<void> ensureReady() async {
    if (!_isAndroid || _registered) return;
    await _invoke<void>('register');
    _registered = true;
  }

  Future<void> showImage(Uint8List pngBytes) async {
    if (pngBytes.isEmpty) return;
    await ensureReady();
    await _invoke<void>('showImage', pngBytes);
  }

  Future<void> showText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await ensureReady();
    await _invoke<void>('showText', trimmed);
  }

  Future<void> showProgress(double fraction) async {
    await ensureReady();
    await _invoke<void>('showProgress', fraction.clamp(0.0, 1.0));
  }

  Future<void> clear() async {
    _registered = false;
    await _invoke<void>('clear');
  }

  Future<void> dispose() async {
    _registered = false;
    await _invoke<void>('dispose');
  }

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    if (!_isAndroid) return null;
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
