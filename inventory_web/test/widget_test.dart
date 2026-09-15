import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_web/main.dart';

void main() {
  testWidgets('shows the ERPNext sign-in screen', (tester) async {
    await tester.pumpWidget(const InventoryWebApp());

    expect(find.text('Sign in to inventory'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
