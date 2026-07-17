import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nothing_glyph_matrix/nothing_glyph_matrix.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GlyphMatrixExampleApp());
}

class GlyphMatrixExampleApp extends StatefulWidget {
  const GlyphMatrixExampleApp({super.key});

  @override
  State<GlyphMatrixExampleApp> createState() => _GlyphMatrixExampleAppState();
}

class _GlyphMatrixExampleAppState extends State<GlyphMatrixExampleApp> {
  final _display = GlyphMatrixDisplay();
  var _ready = false;
  var _enabled = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _display.attach();
    await _display.initialize();
    if (_display.supported) {
      try {
        final logo = await rootBundle.load('assets/logo.png');
        await _display.setIdleImage(logo.buffer.asUint8List());
      } catch (_) {
        // Example asset optional.
      }
    }
    if (mounted) {
      setState(() {
        _ready = true;
        _enabled = _display.enabled && _display.supported;
      });
    }
  }

  @override
  void dispose() {
    _display.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Glyph Matrix Example')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              !_ready
                  ? 'Checking device…'
                  : _display.supported
                  ? 'Nothing Glyph Matrix detected'
                  : 'Not a Glyph Matrix device (safe no-op)',
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Enabled'),
              value: _enabled && _display.supported,
              onChanged: !_ready || !_display.supported
                  ? null
                  : (value) async {
                      await _display.setEnabled(value);
                      setState(() => _enabled = value);
                    },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _display.showText('Hi'),
              child: const Text('Show text: Hi'),
            ),
            FilledButton(
              onPressed: () => _display.showSeconds(60),
              child: const Text('Rest 60s'),
            ),
            FilledButton(
              onPressed: () => _display.setProgress(0.35),
              child: const Text('Progress 35%'),
            ),
            FilledButton(
              onPressed: () => _display.clearRest(),
              child: const Text('Clear rest → idle/progress'),
            ),
            FilledButton(
              onPressed: () => _display.celebrate(hasPr: true),
              child: const Text('Celebrate PR'),
            ),
            OutlinedButton(
              onPressed: () => _display.matrix.clear(),
              child: const Text('Clear matrix'),
            ),
          ],
        ),
      ),
    );
  }
}
