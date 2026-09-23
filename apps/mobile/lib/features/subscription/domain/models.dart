enum BillingPeriod { monthly, yearly }

/// One row of the `plans` catalog. Prices are the list price from the
/// database (yearly_price is computed there). Once Google Play Billing is
/// wired up, the price shown at checkout must be the localized price
/// Play returns, never these values.
class CatalogPlan {
  const CatalogPlan({
    required this.id,
    required this.code,
    required this.name,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.yearlyDiscount,
    required this.maxTables,
    required this.maxWaiters,
    required this.maxAreas,
    required this.maxBranches,
    required this.qrMenuEnabled,
  });

  factory CatalogPlan.fromRow(Map<String, dynamic> row) {
    return CatalogPlan(
      id: row['id'] as String,
      code: row['code'] as String,
      name: row['name'] as String,
      monthlyPrice: (row['monthly_price'] as num).toDouble(),
      yearlyPrice: (row['yearly_price'] as num).toDouble(),
      yearlyDiscount: (row['yearly_discount'] as num).toDouble(),
      maxTables: row['max_tables'] as int?,
      maxWaiters: row['max_waiters'] as int?,
      maxAreas: row['max_areas'] as int?,
      maxBranches: row['max_branches'] as int?,
      qrMenuEnabled: row['qr_menu_enabled'] as bool,
    );
  }

  final String id;
  final String code;
  final String name;
  final double monthlyPrice;
  final double yearlyPrice;
  final double yearlyDiscount;
  final int? maxTables;
  final int? maxWaiters;
  final int? maxAreas;
  final int? maxBranches;
  final bool qrMenuEnabled;

  double priceFor(BillingPeriod period) =>
      period == BillingPeriod.monthly ? monthlyPrice : yearlyPrice;

  /// Feature bullets derived only from real plan columns / existing
  /// modules -- same list as the web's planFeatures().
  List<String> get features {
    String limit(int? value, String unit) =>
        value == null ? 'Sınırsız $unit' : '$value $unit';
    return [
      limit(maxBranches ?? 1, 'işletme'),
      limit(maxTables, 'masa'),
      limit(maxWaiters, 'garson'),
      limit(maxAreas, 'alan'),
      'Adisyon, kasa ve mutfak ekranları',
      'Satış raporları',
      if (qrMenuEnabled) 'QR Menü',
    ];
  }
}

/// The business's current subscription as the database sees it. Display
/// only -- whether the business may open orders or add tables is decided
/// by database triggers, never by this object.
class BusinessSubscription {
  const BusinessSubscription({
    required this.status,
    required this.trialEndsAt,
    required this.planId,
    required this.planName,
    required this.maxTables,
    required this.maxWaiters,
    required this.maxAreas,
    required this.tableCount,
    required this.waiterCount,
    required this.areaCount,
    this.playExpiryTime,
    this.playAutoRenewing,
  });

  final String status;
  final DateTime trialEndsAt;
  final String? planId;
  final String? planName;
  final int? maxTables;
  final int? maxWaiters;
  final int? maxAreas;
  final int tableCount;
  final int waiterCount;
  final int areaCount;
  final DateTime? playExpiryTime;
  final bool? playAutoRenewing;

  bool get isTrial => status == 'TRIAL';

  int trialDaysLeft(DateTime now) =>
      (trialEndsAt.difference(now).inHours / 24).ceil();

  String get statusLabel => switch (status) {
    'TRIAL' => 'Ücretsiz deneme',
    'ACTIVE' => 'Aktif',
    'GRACE_PERIOD' => 'Ödeme bekleniyor',
    'EXPIRED' => 'Süresi doldu',
    'SUSPENDED' => 'Askıya alındı',
    'CANCELLED' => 'İptal edildi',
    _ => status,
  };
}
