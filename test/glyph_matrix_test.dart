import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_glyph_matrix/nothing_glyph_matrix.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('nothing_glyph_matrix');
  final log = <MethodCall>[];

  setUp(() {
    log.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          log.add(call);
          if (call.method == 'isSupported') return true;
          return null;
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('formatRestCountdown compact under one minute', () {
    expect(formatRestCountdown(45, compact: true), '45');
    expect(formatRestCountdown(90, compact: true), '1:30');
  });

  test('GlyphMatrix showText invokes channel after ensureReady', () async {
    final matrix = GlyphMatrix(channel: channel);
    await matrix.showText('PR');
    expect(log.map((c) => c.method), containsAll(['register', 'showText']));
  });

  test('GlyphMatrixDisplay priority prefers peek over rest', () async {
    final matrix = GlyphMatrix(channel: channel);
    final display = GlyphMatrixDisplay(matrix: matrix);
    display.enabled = true;
    display.supported = true;

    await display.showSeconds(60);
    await display.showPeek('80x8', duration: const Duration(hours: 1));
    await Future<void>.delayed(Duration.zero);

    expect(log.last.method, 'showText');
    expect(log.last.arguments, '80x8');
  });
}
