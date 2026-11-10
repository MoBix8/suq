import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suq_supplier/app.dart';
import 'package:suq_supplier/providers.dart';

void main() {
  testWidgets('shows the supplier sign-in form', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: const SuqSupplierApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Supplier sign in'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
