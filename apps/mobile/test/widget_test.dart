import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adisyon/features/auth/presentation/login_screen.dart';

void main() {
  testWidgets('Login screen renders the sign-in form', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    expect(find.text('MK Adisyon'), findsOneWidget);
    expect(find.text('E-posta'), findsOneWidget);
    expect(find.text('Şifre'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Giriş Yap'), findsOneWidget);
  });
}
