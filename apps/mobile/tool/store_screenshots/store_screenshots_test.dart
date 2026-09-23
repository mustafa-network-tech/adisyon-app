// Renders the real app screens with demo data at phone resolution
// (phone 1080x1920, 7" and 10" tablet 1920x1080) for the Google Play
// listing. Not part of `flutter test`:
//
//   flutter test tool/store_screenshots/store_screenshots_test.dart
//
// Output: build/store_screenshots/raw/{phone,tablet7,tablet10}/*.png. Then run
// tool/store_screenshots/frame_screenshots.py to add captions.
// Uses the Roboto + Material Icons fonts shipped with the Flutter SDK so
// text renders as on a device (tests use a box font by default).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adisyon/core/theme/app_theme.dart';
import 'package:adisyon/features/auth/application/role_context.dart';
import 'package:adisyon/features/cashier/application/cashier_providers.dart';
import 'package:adisyon/features/cashier/domain/models.dart';
import 'package:adisyon/features/cashier/presentation/cashier_home_screen.dart';
import 'package:adisyon/features/cashier/presentation/order_screen.dart';
import 'package:adisyon/features/kitchen/application/kitchen_providers.dart';
import 'package:adisyon/features/kitchen/domain/models.dart';
import 'package:adisyon/features/kitchen/presentation/kitchen_screen.dart';
import 'package:adisyon/features/subscription/application/subscription_providers.dart';
import 'package:adisyon/features/subscription/domain/models.dart';
import 'package:adisyon/features/subscription/domain/play_offers.dart';
import 'package:adisyon/features/subscription/presentation/subscription_screen.dart';
import 'package:adisyon/features/waiter/application/cart_controller.dart';
import 'package:adisyon/features/waiter/application/waiter_providers.dart';
import 'package:adisyon/features/waiter/domain/models.dart';
import 'package:adisyon/features/waiter/presentation/menu_screen.dart';
import 'package:adisyon/features/waiter/presentation/table_screen.dart';
import 'package:adisyon/features/waiter/presentation/waiter_home_screen.dart';

/// Device profiles rendered for the listing. Each writes to
/// `build/store_screenshots/raw/<name>/`.
class _Profile {
  const _Profile(this.name, this.logicalSize, this.pixelRatio, this.screens);

  final String name;
  final Size logicalSize;
  final double pixelRatio;

  /// Screen ids (see _screens) captured for this profile.
  final List<String> screens;
}

const _allScreens = [
  '01_garson_masalar',
  '02_masa_adisyon',
  '03_menu_siparis',
  '04_mutfak',
  '05_kasa',
  '06_odeme',
  '07_abonelik',
];
const _tabletScreens = [
  '01_garson_masalar',
  '03_menu_siparis',
  '04_mutfak',
  '05_kasa',
  '07_abonelik',
];

const _profiles = [
  // Phone, portrait: 411x731 dp x2.625 = 1080x1920.
  _Profile('phone', Size(411.43, 731.43), 2.625, _allScreens),
  // 7" tablet, landscape: 1024x576 dp x1.875 = 1920x1080.
  _Profile('tablet7', Size(1024, 576), 1.875, _tabletScreens),
  // 10" tablet, landscape: 1280x720 dp x1.5 = 1920x1080.
  _Profile('tablet10', Size(1280, 720), 1.5, _tabletScreens),
];

final Map<String, Widget> _screens = {
  '01_garson_masalar': const WaiterHomeScreen(),
  '02_masa_adisyon': const TableScreen(tableId: 't5'),
  '03_menu_siparis': const MenuScreen(tableId: 't5'),
  '04_mutfak': const KitchenScreen(),
  '05_kasa': const CashierHomeScreen(),
  '06_odeme': const OrderScreen(orderId: 'o4'),
  '07_abonelik': const SubscriptionScreen(),
};

Future<void> _loadFonts() async {
  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final fontsDir = '$flutterRoot/bin/cache/artifacts/material_fonts';

  Future<ByteData> read(String name) async =>
      ByteData.sublistView(await File('$fontsDir/$name').readAsBytes());

  // 'Roboto' for styles that name it; the test binding's default families
  // for styles that name none (on a device these fall back to Roboto).
  for (final family in ['Roboto', 'FlutterTest', 'Ahem']) {
    final loader = FontLoader(family)
      ..addFont(read('roboto-regular.ttf'))
      ..addFont(read('roboto-medium.ttf'))
      ..addFont(read('roboto-bold.ttf'))
      ..addFont(read('roboto-black.ttf'));
    await loader.load();
  }
  final icons = FontLoader('MaterialIcons')
    ..addFont(read('materialicons-regular.otf'));
  await icons.load();
}

const _business = RoleContext(
  role: AppRole.waiter,
  businessId: 'demo-business',
  businessName: 'Lale Cafe & Restoran',
);

final _now = DateTime.now();

// ---------------------------------------------------------------------------
// Demo data
// ---------------------------------------------------------------------------
const _areas = [
  AreaModel(id: 'a1', name: 'Salon'),
  AreaModel(id: 'a2', name: 'Bahçe'),
  AreaModel(id: 'a3', name: 'Teras'),
];

final _tables = [
  for (var i = 1; i <= 12; i++)
    TableModel(
      id: 't$i',
      name: 'Masa $i',
      areaId: 'a1',
      status: switch (i) {
        2 || 5 || 6 || 9 || 11 => 'OCCUPIED',
        4 || 10 => 'CHECK_REQUESTED',
        _ => 'AVAILABLE',
      },
    ),
];

const _categories = [
  CategoryModel(id: 'c1', name: 'Kahvaltı'),
  CategoryModel(id: 'c2', name: 'Ana Yemek'),
  CategoryModel(id: 'c3', name: 'Tatlı'),
  CategoryModel(id: 'c4', name: 'İçecek'),
];

const _products = [
  ProductModel(
    id: 'p1',
    name: 'Serpme Kahvaltı (2 kişilik)',
    price: 780,
    categoryId: 'c1',
  ),
  ProductModel(id: 'p2', name: 'Menemen', price: 190, categoryId: 'c1'),
  ProductModel(id: 'p3', name: 'Sucuklu Yumurta', price: 210, categoryId: 'c1'),
  ProductModel(id: 'p4', name: 'Izgara Köfte', price: 340, categoryId: 'c2'),
  ProductModel(id: 'p5', name: 'Tavuk Şiş', price: 310, categoryId: 'c2'),
  ProductModel(id: 'p6', name: 'Mantı', price: 260, categoryId: 'c2'),
  ProductModel(id: 'p7', name: 'Künefe', price: 220, categoryId: 'c3'),
  ProductModel(id: 'p8', name: 'Sütlaç', price: 140, categoryId: 'c3'),
  ProductModel(id: 'p9', name: 'Türk Kahvesi', price: 90, categoryId: 'c4'),
  ProductModel(id: 'p10', name: 'Çay', price: 30, categoryId: 'c4'),
  ProductModel(
    id: 'p11',
    name: 'Taze Portakal Suyu',
    price: 120,
    categoryId: 'c4',
  ),
];

const _orderItems = [
  OrderItemModel(
    id: 'i1',
    orderId: 'o5',
    productName: 'Izgara Köfte',
    unitPrice: 340,
    quantity: 2,
    note: 'Biri az pişmiş',
    status: 'SERVED',
  ),
  OrderItemModel(
    id: 'i2',
    orderId: 'o5',
    productName: 'Mantı',
    unitPrice: 260,
    quantity: 1,
    note: null,
    status: 'READY',
  ),
  OrderItemModel(
    id: 'i3',
    orderId: 'o5',
    productName: 'Taze Portakal Suyu',
    unitPrice: 120,
    quantity: 2,
    note: null,
    status: 'PREPARING',
  ),
  OrderItemModel(
    id: 'i4',
    orderId: 'o5',
    productName: 'Künefe',
    unitPrice: 220,
    quantity: 1,
    note: 'Kaymaklı',
    status: 'NEW',
  ),
];

KitchenItem _kitchenItem(
  String id,
  String order,
  String name,
  int qty,
  String status, {
  String? note,
  int minutesAgo = 5,
}) => KitchenItem(
  id: id,
  orderId: order,
  productName: name,
  quantity: qty,
  note: note,
  status: status,
  createdAt: _now.subtract(Duration(minutes: minutesAgo)),
);

final _kitchenTickets = [
  KitchenTicket(
    orderId: 'o2',
    tableName: 'Masa 2',
    openedAt: _now.subtract(const Duration(minutes: 18)),
    items: [
      _kitchenItem(
        'k1',
        'o2',
        'Serpme Kahvaltı (2 kişilik)',
        1,
        'PREPARING',
        minutesAgo: 17,
      ),
      _kitchenItem(
        'k2',
        'o2',
        'Menemen',
        1,
        'READY',
        note: 'Soğanlı',
        minutesAgo: 16,
      ),
    ],
  ),
  KitchenTicket(
    orderId: 'o5',
    tableName: 'Masa 5',
    openedAt: _now.subtract(const Duration(minutes: 9)),
    items: [
      _kitchenItem('k3', 'o5', 'Mantı', 1, 'READY', minutesAgo: 8),
      _kitchenItem(
        'k4',
        'o5',
        'Künefe',
        1,
        'NEW',
        note: 'Kaymaklı',
        minutesAgo: 2,
      ),
    ],
  ),
  KitchenTicket(
    orderId: 'o9',
    tableName: 'Masa 9',
    openedAt: _now.subtract(const Duration(minutes: 4)),
    items: [
      _kitchenItem(
        'k5',
        'o9',
        'Izgara Köfte',
        2,
        'NEW',
        note: 'Biri az pişmiş',
        minutesAgo: 3,
      ),
      _kitchenItem('k6', 'o9', 'Tavuk Şiş', 1, 'NEW', minutesAgo: 3),
    ],
  ),
];

final _cashierTickets = [
  CashierTicket(
    orderId: 'o4',
    tableName: 'Masa 4',
    checkRequested: true,
    openedAt: _now.subtract(const Duration(minutes: 52)),
    total: 1180,
  ),
  CashierTicket(
    orderId: 'o10',
    tableName: 'Masa 10',
    checkRequested: true,
    openedAt: _now.subtract(const Duration(minutes: 35)),
    total: 640,
  ),
  CashierTicket(
    orderId: 'o2',
    tableName: 'Masa 2',
    checkRequested: false,
    openedAt: _now.subtract(const Duration(minutes: 18)),
    total: 970,
  ),
  CashierTicket(
    orderId: 'o5',
    tableName: 'Masa 5',
    checkRequested: false,
    openedAt: _now.subtract(const Duration(minutes: 9)),
    total: 1400,
  ),
  CashierTicket(
    orderId: 'o9',
    tableName: 'Masa 9',
    checkRequested: false,
    openedAt: _now.subtract(const Duration(minutes: 4)),
    total: 990,
  ),
];

const _cashierItems = [
  CashierOrderItem(
    id: 'x1',
    productName: 'Serpme Kahvaltı (2 kişilik)',
    unitPrice: 780,
    quantity: 1,
    note: null,
    status: 'SERVED',
  ),
  CashierOrderItem(
    id: 'x2',
    productName: 'Sucuklu Yumurta',
    unitPrice: 210,
    quantity: 1,
    note: null,
    status: 'SERVED',
  ),
  CashierOrderItem(
    id: 'x3',
    productName: 'Çay',
    unitPrice: 30,
    quantity: 4,
    note: null,
    status: 'SERVED',
  ),
  CashierOrderItem(
    id: 'x4',
    productName: 'Türk Kahvesi',
    unitPrice: 90,
    quantity: 1,
    note: null,
    status: 'SERVED',
  ),
  CashierOrderItem(
    id: 'x5',
    productName: 'Menemen',
    unitPrice: 190,
    quantity: 1,
    note: 'İptal: yanlış sipariş',
    status: 'VOID',
  ),
];

const _cashierPayments = [
  CashierPayment(id: 'y1', method: 'CARD', amount: 600, status: 'COMPLETED'),
];

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
  'google_play_product_id': 'demo_$code',
  'google_play_monthly_base_plan_id': 'monthly',
  'google_play_yearly_base_plan_id': 'yearly',
});

final _plans = [
  _plan('p1', 'standard', 'Standart', 10, 399, 4309.2, 10, 2, 1, false),
  _plan('p2', 'super', 'Süper', 20, 799, 8629.2, 20, 5, 3, false),
  _plan('p3', 'ultra_super', 'Ultra Süper', 30, 1899, 20509.2, 35, 10, 5, true),
];

PlayPlanOffer _campaign(String product, String price) => PlayPlanOffer(
  productId: product,
  basePlanId: 'monthly',
  offerId: 'acilis',
  offerToken: '$product-acilis',
  phases: [
    const PlayPricingPhase(
      priceMicros: 0,
      formattedPrice: 'Ücretsiz',
      currencyCode: 'TRY',
      billingPeriod: 'P14D',
      billingCycleCount: 1,
      isInfinite: false,
    ),
    PlayPricingPhase(
      priceMicros: 1,
      formattedPrice: price,
      currencyCode: 'TRY',
      billingPeriod: 'P1M',
      billingCycleCount: 0,
      isInfinite: true,
    ),
  ],
);

final _entitlement = Entitlement.fromRow(
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
  tableCount: 12,
  waiterCount: 3,
  areaCount: 3,
);

class _DemoCart extends CartController {
  @override
  List<CartItem> build() => [
    CartItem(product: _products[3], quantity: 2, note: 'Biri az pişmiş'),
    CartItem(product: _products[8], quantity: 2),
  ];
}

class _IdlePurchase extends PurchaseController {
  @override
  PurchaseFlowState build() => const PurchaseFlowState(PurchaseFlowStatus.idle);
}

// ---------------------------------------------------------------------------
// Capture
// ---------------------------------------------------------------------------
final _overrides = [
  roleContextProvider.overrideWith((ref) async => _business),
  areasProvider.overrideWith((ref) async => _areas),
  tablesStreamProvider.overrideWith((ref) => Stream.value(_tables)),
  categoriesProvider.overrideWith((ref) async => _categories),
  productsProvider.overrideWith((ref) async => _products),
  openOrderProvider.overrideWith(
    (ref, tableId) async => const OrderModel(
      id: 'o5',
      tableId: 't5',
      status: 'OPEN',
      checkRequested: false,
    ),
  ),
  orderItemsStreamProvider.overrideWith(
    (ref, orderId) => Stream.value(_orderItems),
  ),
  cartControllerProvider.overrideWith(_DemoCart.new),
  kitchenTicketsProvider.overrideWith(
    (ref) => AsyncValue.data(_kitchenTickets),
  ),
  cashierTicketsProvider.overrideWith(
    (ref) => AsyncValue.data(_cashierTickets),
  ),
  orderStatusStreamProvider.overrideWith(
    (ref, orderId) => Stream.value('OPEN'),
  ),
  cashierOrderItemsStreamProvider.overrideWith(
    (ref, orderId) => Stream.value(_cashierItems),
  ),
  cashierPaymentsStreamProvider.overrideWith(
    (ref, orderId) => Stream.value(_cashierPayments),
  ),
  planCatalogProvider.overrideWith((ref) async => _plans),
  entitlementProvider.overrideWith((ref) async => _entitlement),
  playOffersProvider.overrideWith(
    (ref) async => {
      'demo_standard': [_campaign('demo_standard', '₺399,00')],
      'demo_super': [_campaign('demo_super', '₺799,00')],
      'demo_ultra_super': [_campaign('demo_ultra_super', '₺1.899,00')],
    },
  ),
  purchaseControllerProvider.overrideWith(_IdlePurchase.new),
];

/// AppTheme's button text styles name no font family; on a device that
/// falls back to Roboto, in tests to a box font. Pin it for rendering.
ThemeData _screenshotTheme() {
  final theme = AppTheme.light();
  WidgetStatePropertyAll<TextStyle?> roboto(ButtonStyle? style) =>
      WidgetStatePropertyAll(
        (style?.textStyle?.resolve({}) ?? const TextStyle()).copyWith(
          fontFamily: 'Roboto',
        ),
      );
  return theme.copyWith(
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: theme.elevatedButtonTheme.style?.copyWith(
        textStyle: roboto(theme.elevatedButtonTheme.style),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: theme.outlinedButtonTheme.style?.copyWith(
        textStyle: roboto(theme.outlinedButtonTheme.style),
      ),
    ),
  );
}

Future<void> _capture(
  WidgetTester tester,
  _Profile profile,
  String name,
  Widget screen,
) async {
  tester.view.physicalSize = profile.logicalSize * profile.pixelRatio;
  tester.view.devicePixelRatio = profile.pixelRatio;
  final boundaryKey = GlobalKey();

  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides,
      child: RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _screenshotTheme(),
          home: screen,
        ),
      ),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }

  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: profile.pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('build/store_screenshots/raw/${profile.name}')
      ..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });

  await tester.pumpWidget(const SizedBox.shrink());
  tester.view.reset();
}

void main() {
  setUpAll(_loadFonts);

  for (final profile in _profiles) {
    for (final name in profile.screens) {
      testWidgets(
        '${profile.name} $name',
        (tester) => _capture(tester, profile, name, _screens[name]!),
      );
    }
  }
}
