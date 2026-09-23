import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:adisyon/core/theme/app_theme.dart';
import 'package:adisyon/features/auth/application/role_context.dart';
import 'package:adisyon/features/cashier/application/cashier_providers.dart';
import 'package:adisyon/features/cashier/domain/models.dart';
import 'package:adisyon/features/cashier/presentation/order_screen.dart';
import 'package:adisyon/features/kitchen/application/kitchen_providers.dart';
import 'package:adisyon/features/kitchen/domain/models.dart';
import 'package:adisyon/features/kitchen/presentation/kitchen_screen.dart';

// Regression tests for layouts that broke on a phone-sized screen. Any
// RenderFlex overflow or layout exception fails these tests.

const _phone = Size(360, 740);

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  List<Override> overrides,
) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        roleContextProvider.overrideWith(
          (ref) async => const RoleContext(
            role: AppRole.cashier,
            businessId: 'b1',
            businessName: 'Test',
          ),
        ),
        ...overrides,
      ],
      child: MaterialApp(theme: AppTheme.light(), home: screen),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets(
    'cashier bill without payments renders (cancel button in a Row)',
    (tester) async {
      await _pump(tester, const OrderScreen(orderId: 'o1'), [
        orderStatusStreamProvider.overrideWith(
          (ref, id) => Stream.value('OPEN'),
        ),
        cashierOrderItemsStreamProvider.overrideWith(
          (ref, id) => Stream.value(const [
            CashierOrderItem(
              id: 'i1',
              productName: 'Izgara Köfte',
              unitPrice: 340,
              quantity: 2,
              note: null,
              status: 'SERVED',
            ),
          ]),
        ),
        cashierPaymentsStreamProvider.overrideWith(
          (ref, id) => Stream.value(const <CashierPayment>[]),
        ),
      ]);

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('İptal Et'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('İptal Et'), findsOneWidget);
      expect(find.text('Hesabı Kapat'), findsOneWidget);
    },
  );

  testWidgets('kitchen board fits a phone with long tickets', (tester) async {
    final now = DateTime.now();
    KitchenItem item(String id, String name) => KitchenItem(
      id: id,
      orderId: 'o1',
      productName: name,
      quantity: 1,
      note: 'Not: az acılı, soğansız',
      status: 'NEW',
      createdAt: now,
    );

    await _pump(tester, const KitchenScreen(), [
      kitchenTicketsProvider.overrideWith(
        (ref) => AsyncValue.data([
          KitchenTicket(
            orderId: 'o1',
            tableName: 'Masa 1',
            openedAt: now,
            items: [
              for (var i = 0; i < 6; i++)
                item('k$i', 'Serpme Kahvaltı (2 kişilik) $i'),
            ],
          ),
        ]),
      ),
    ]);

    expect(tester.takeException(), isNull);
    expect(find.text('Masa 1'), findsOneWidget);
  });
}
