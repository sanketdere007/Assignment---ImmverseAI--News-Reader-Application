import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicknews/app/app.dart';

void main() {
  testWidgets('QuickNewsApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: QuickNewsApp(),
      ),
    );
    expect(find.text('QuickNews'), findsOneWidget);
  });
}
