import 'package:flutter_test/flutter_test.dart';

import 'package:cpool_app/app.dart';

void main() {
  testWidgets('CPool app loads splash', (WidgetTester tester) async {
    await tester.pumpWidget(const CPoolApp());
    await tester.pump();
    expect(find.text('CPool'), findsWidgets);
  });
}
