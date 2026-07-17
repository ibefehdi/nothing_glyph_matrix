import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nothing_glyph_matrix/nothing_glyph_matrix.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('isSupported returns a bool', (tester) async {
    final matrix = GlyphMatrix();
    final supported = await matrix.isSupported();
    expect(supported, isA<bool>());
  });
}
