import 'package:flutter_test/flutter_test.dart';
import 'package:peekaboo_mvp/app/peekaboo_app.dart';

void main() {
  testWidgets('Peekaboo app shows home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PeekabooApp());
    await tester.pumpAndSettle();

    expect(find.text('Peekaboo'), findsOneWidget);
    expect(find.text('Today’s book'), findsOneWidget);
  });
}
