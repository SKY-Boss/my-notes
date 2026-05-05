import 'package:flutter_test/flutter_test.dart';
import 'package:my_notes/app.dart';

void main() {
  testWidgets('App launches without error', (WidgetTester tester) async {
    await tester.pumpWidget(const NotesApp());
    expect(find.text('全部笔记'), findsOneWidget);
  });
}
