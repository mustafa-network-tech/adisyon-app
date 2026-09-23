import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adisyon/core/utils/currency.dart';
import 'package:adisyon/features/subscription/application/subscription_providers.dart';
import 'package:adisyon/features/subscription/domain/models.dart';
import 'package:adisyon/features/subscription/domain/play_offers.dart';
import 'package:adisyon/features/subscription/presentation/subscription_screen.dart';

// Mirrors the seeded rows in 20260923000029 (yearly_price as the
// database computes it). Play ids are test values, not real products.
CatalogPlan _plan(
  String id,
  String code,
  String name,
  int order,
  double monthly,
  double yearly,
  int tables,
  int waiters,
  int areas,
  bool qr,
) => CatalogPlan.fromRow({
  'id': id,
  'code': code,
  'name': name,
  'sort_order': order,
  'monthly_price': monthly,
  'yearly_price': yearly,
  'yearly_discount': 10,
  'max_tables': tables,
  'max_waiters': waiters,
  'max_areas': areas,
  'max_branches': 1,
  'qr_menu_enabled': qr,
  'google_play_product_id': 'test_$code',
  'google_play_monthly_base_plan_id': 'monthly',
  'google_play_yearly_base_plan_id': 'yearly',
});

final _plans = [
  _plan('p1', 'standard', 'Standart', 10, 399, 4309.2, 10, 2, 1, false),
  _plan('p2', 'super', 'Süper', 20, 799, 8629.2, 20, 5, 3, false),
  _plan('p3', 'ultra_super', 'Ultra Süper', 30, 1899, 20509.2, 35, 10, 5, true),
];

PlayPricingPhase _phase(
  int micros,
  String price,
  String period, {
  bool infinite = true,
  int cycles = 0,
}) => PlayPricingPhase(
  priceMicros: micros,
  formattedPrice: price,
  currencyCode: 'TRY',
  billingPeriod: period,
  billingCycleCount: cycles,
  isInfinite: infinite,
);

PlayPlanOffer _offer(
  String product,
  String basePlan, {
  String? offerId,
  List<PlayPricingPhase>? phases,
}) => PlayPlanOffer(
  productId: product,
  basePlanId: basePlan,
  offerId: offerId,
  offerToken: '$product-$basePlan-${offerId ?? 'base'}',
  phases: phases ?? [_phase(399000000, '₺399,00', 'P1M')],
);

Entitlement _trialEntitlement() => Entitlement.fromRow(
  const {
    'subscription_status': 'TRIAL',
    'is_operational': true,
    'access_source': 'APP_TRIAL',
    'app_trial_days_left': 3,
    'subscribed_plan_id': null,
    'subscribed_plan_code': null,
    'subscribed_plan_name': null,
    'effective_plan_name': 'Ultra Süper',
    'max_tables': 35,
    'max_waiters': 10,
    'max_areas': 5,
    'play_product_id': null,
    'play_base_plan_id': null,
    'play_expiry_time': null,
    'play_auto_renewing': null,
  },
  tableCount: 4,
  waiterCount: 1,
  areaCount: 1,
);

class _IdlePurchaseController extends PurchaseController {
  @override
  PurchaseFlowState build() => const PurchaseFlowState(PurchaseFlowStatus.idle);
}

Widget _app({required Map<String, List<PlayPlanOffer>>? offers}) {
  return ProviderScope(
    overrides: [
      planCatalogProvider.overrideWith((ref) async => _plans),
      entitlementProvider.overrideWith((ref) async => _trialEntitlement()),
      playOffersProvider.overrideWith((ref) async => offers),
      purchaseControllerProvider.overrideWith(_IdlePurchaseController.new),
    ],
    child: const MaterialApp(home: SubscriptionScreen()),
  );
}

void main() {
  test('formatTl uses Turkish grouping and drops zero kuruş', () {
    expect(formatTl(399), '399 TL');
    expect(formatTl(1899), '1.899 TL');
    expect(formatTl(4309.2), '4.309,20 TL');
    expect(formatTl(20509.2), '20.509,20 TL');
  });

  test('plan features come only from plan columns', () {
    expect(_plans[0].features, contains('10 masa'));
    expect(_plans[0].features, isNot(contains('QR Menü')));
    expect(_plans[2].features, contains('QR Menü'));
  });

  group('Play offer text comes from Play pricing phases', () {
    test('ISO periods', () {
      expect(describeIsoPeriod('P15D'), '15 gün');
      expect(describeIsoPeriod('P14D'), '14 gün');
      expect(describeIsoPeriod('P1W', cycles: 2), '2 hafta');
      expect(describeIsoPeriod('P1M'), '1 ay');
      expect(describeBillingUnit('P1M'), 'ay');
      expect(describeBillingUnit('P1Y'), 'yıl');
      expect(describeBillingUnit('P3M'), '3 ay');
    });

    test('campaign length is whatever Play returns', () {
      for (final days in [7, 14, 15, 20]) {
        final offer = _offer(
          'test_standard',
          'monthly',
          offerId: 'launch',
          phases: [
            _phase(0, 'Ücretsiz', 'P${days}D', infinite: false, cycles: 1),
            _phase(399000000, '₺399,00', 'P1M'),
          ],
        );
        expect(describeOffer(offer), '$days gün ücretsiz, ardından ₺399,00/ay');
      }
    });

    test('base plan without campaign', () {
      expect(
        describeOffer(
          _offer(
            'test_standard',
            'yearly',
            phases: [_phase(4309200000, '₺4.309,20', 'P1Y')],
          ),
        ),
        '₺4.309,20/yıl',
      );
    });

    test(
      'campaign offer only for new subscriptions, never for plan change',
      () {
        final base = _offer('test_super', 'monthly');
        final campaign = _offer(
          'test_super',
          'monthly',
          offerId: 'launch',
          phases: [
            _phase(0, 'Ücretsiz', 'P15D', infinite: false, cycles: 1),
            _phase(799000000, '₺799,00', 'P1M'),
          ],
        );
        expect(selectOffer([base, campaign], allowCampaign: true), campaign);
        expect(selectOffer([base, campaign], allowCampaign: false), base);
        expect(selectOffer([base], allowCampaign: true), base);
        expect(selectOffer(const [], allowCampaign: true), isNull);
      },
    );
  });

  for (final width in [360.0, 1024.0]) {
    testWidgets(
      'shows Play campaign text and server trial days (width $width)',
      (tester) async {
        tester.view.physicalSize = Size(width, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _app(
            offers: {
              'test_standard': [
                _offer('test_standard', 'monthly'),
                _offer(
                  'test_standard',
                  'monthly',
                  offerId: 'launch',
                  phases: [
                    _phase(0, 'Ücretsiz', 'P15D', infinite: false, cycles: 1),
                    _phase(399000000, '₺399,00', 'P1M'),
                  ],
                ),
              ],
            },
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Ücretsiz deneme'), findsOneWidget);
        expect(find.textContaining('3 günü kaldı'), findsOneWidget);
        expect(
          find.text('15 gün ücretsiz, ardından ₺399,00/ay'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(ElevatedButton, 'Ücretsiz dönemi başlat'),
          findsOneWidget,
        );
        // Plans without Play offers fall back to the list price, not buyable.
        expect(find.textContaining('1.899 TL'), findsOneWidget);
      },
    );
  }

  testWidgets('fail-safe when Play billing is not configured', (tester) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(offers: null));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Abonelik servisi şu an kullanılamıyor'),
      findsOneWidget,
    );
    final buttons = tester.widgetList<ElevatedButton>(
      find.byType(ElevatedButton),
    );
    expect(buttons, isNotEmpty);
    expect(buttons.every((button) => button.onPressed == null), isTrue);

    await tester.ensureVisible(find.text('Yıllık (%10 indirim)'));
    await tester.tap(find.text('Yıllık (%10 indirim)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('4.309,20 TL'), findsOneWidget);
  });
}
