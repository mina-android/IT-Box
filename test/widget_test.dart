import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:itbox/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('IT Box smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ITBoxApp());
  });
}
