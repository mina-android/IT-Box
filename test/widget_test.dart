import 'package:flutter_test/flutter_test.dart';
import 'package:itbox/main.dart';

void main() {
  testWidgets('IT Box smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ITBoxApp());
  });
}
