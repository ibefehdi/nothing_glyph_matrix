import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_glyph_matrix_example/main.dart';

void main() {
  testWidgets('example app loads', (tester) async {
    await tester.pumpWidget(const GlyphMatrixExampleApp());
    await tester.pump();
    expect(find.textContaining('Glyph Matrix'), findsWidgets);
  });
}
