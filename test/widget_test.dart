import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('App renders onboarding screen', (WidgetTester tester) async {
    await tester.pumpWidget(const EsepApp());

    expect(find.text('Дели всё честно'), findsOneWidget);
  });
}
