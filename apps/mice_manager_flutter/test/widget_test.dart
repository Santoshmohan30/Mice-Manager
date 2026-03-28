import 'package:flutter_test/flutter_test.dart';

import 'package:mice_manager_flutter/app/app.dart';

void main() {
  testWidgets('app shell renders dashboard and mice navigation',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MiceManagerApp());

    expect(find.text('Offline-first lab operations'), findsOneWidget);
    expect(find.text('Mice'), findsWidgets);

    await tester.tap(find.text('Mice').last);
    await tester.pumpAndSettle();

    expect(find.text('Add Mouse'), findsOneWidget);
  });
}
