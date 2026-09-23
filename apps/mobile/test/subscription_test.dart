import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adisyon/core/utils/currency.dart';
import 'package:adisyon/features/subscription/application/subscription_providers.dart';
import 'package:adisyon/features/subscription/domain/models.dart';
import 'package:adisyon/features/subscription/presentation/subscription_screen.dart';

// Mirrors the seeded rows in 20260923000029 (yearly_price as the
// database computes it).
final _plans = [
  CatalogPlan.fromRow(const {
    'id': 'p1',
    'code': 'standard',
    'name': 'Standart',
    'monthly_price': 399,
    'yearly_price': 4309.2,
    'yearly_discount': 10,
    'max_tables': 10,
    'max_waiters': 2,
    'max_areas': 1,
    'max_branches': 1,
    'qr_menu_enabled': false,
  }),
  CatalogPlan.fromRow(const {
    'id': 'p2',
    'code': 'super',
    'name': 'Süper',
    'monthly_price': 799,
    'yearly_price': 8629.2,
    'yearly_discount': 10,
    'max_tables': 20,
    'max_waiters': 5,
    'max_areas': 3,
    'max_branches': 1,
    'qr_menu_enabled': false,
  }),
  CatalogPlan.fromRow(const {
    'id': 'p3',
    'code': 'ultra_super',
    'name': 'Ultra Süper',
    'monthly_price': 1899,
    'yearly_price': 20509.2,
    'yearly_discount': 10,
    'max_tables': 35,
    'max_waiters': 10,
    'max_areas': 5,
    'max_branches': 1,
    'qr_menu_enabled': true,
  }),
];

void main() {
  test('formatTl uses Turkish grouping and drops zero kuruş', () {
    expect(formatTl(399), '399 TL');
    expect(formatTl(1899), '1.899 TL');
    expect(formatTl(4309.2), '4.309,20 TL');
    expect(formatTl(20509.2), '20.509,20 TL');
    expect(formatTl(22788), '22.788 TL');
  });

  test('plan features come only from plan columns', () {
    expect(_plans[0].features, contains('10 masa'));
    expect(_plans[0].features, contains('2 garson'));
    expect(_plans[0].features, isNot(contains('QR Menü')));
    expect(_plans[2].features, contains('QR Menü'));
    expect(_plans[2].features, contains('35 masa'));
  });

  for (final width in [360.0, 1024.0]) {
    testWidgets('subscription screen shows plans and switches to yearly '
        '(width $width)', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            planCatalogProvider.overrideWith((ref) async => _plans),
            businessSubscriptionProvider.overrideWith(
              (ref) async => BusinessSubscription(
                status: 'TRIAL',
                trialEndsAt: DateTime.now().add(const Duration(days: 5)),
                planId: null,
                planName: null,
                maxTables: null,
                maxWaiters: null,
                maxAreas: null,
                tableCount: 4,
                waiterCount: 1,
                areaCount: 1,
              ),
            ),
          ],
          child: const MaterialApp(home: SubscriptionScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ücretsiz deneme'), findsOneWidget);
      expect(find.textContaining('399 TL'), findsOneWidget);
      expect(find.textContaining('1.899 TL'), findsOneWidget);

      await tester.ensureVisible(find.text('Yıllık (%10 indirim)'));
      await tester.tap(find.text('Yıllık (%10 indirim)'));
      await tester.pumpAndSettle();

      expect(find.textContaining('4.309,20 TL'), findsOneWidget);
      expect(find.textContaining('20.509,20 TL'), findsOneWidget);
      // No purchase can be triggered while billing isn't wired up.
      final buttons = tester.widgetList<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Yakında'),
      );
      expect(buttons, isNotEmpty);
      expect(buttons.every((button) => button.onPressed == null), isTrue);
    });
  }
}
