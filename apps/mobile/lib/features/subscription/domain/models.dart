enum BillingPeriod { monthly, yearly }

/// One row of the `plans` catalog. Prices are the list price from the
/// database (yearly_price is computed there). At checkout the price shown
/// and charged is always the one Google Play returns, never these values.
class CatalogPlan {
  const CatalogPlan({
    required this.id,
    required this.code,
    required this.name,
    required this.sortOrder,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.yearlyDiscount,
    required this.maxTables,
    required this.maxWaiters,
    required this.maxAreas,
    required this.maxBranches,
    required this.qrMenuEnabled,
    this.googlePlayProductId,
    this.googlePlayMonthlyBasePlanId,
    this.googlePlayYearlyBasePlanId,
  });

  factory CatalogPlan.fromRow(Map<String, dynamic> row) {
    return CatalogPlan(
      id: row['id'] as String,
      code: row['code'] as String,
      name: row['name'] as String,
      sortOrder: (row['sort_order'] as int?) ?? 0,
      monthlyPrice: (row['monthly_price'] as num).toDouble(),
      yearlyPrice: (row['yearly_price'] as num).toDouble(),
      yearlyDiscount: (row['yearly_discount'] as num).toDouble(),
      maxTables: row['max_tables'] as int?,
      maxWaiters: row['max_waiters'] as int?,
      maxAreas: row['max_areas'] as int?,
      maxBranches: row['max_branches'] as int?,
      qrMenuEnabled: row['qr_menu_enabled'] as bool,
      googlePlayProductId: row['google_play_product_id'] as String?,
      googlePlayMonthlyBasePlanId:
          row['google_play_monthly_base_plan_id'] as String?,
      googlePlayYearlyBasePlanId:
          row['google_play_yearly_base_plan_id'] as String?,
    );
  }

  final String id;
  final String code;
  final String name;
  final int sortOrder;
  final double monthlyPrice;
  final double yearlyPrice;
  final double yearlyDiscount;
  final int? maxTables;
  final int? maxWaiters;
  final int? maxAreas;
  final int? maxBranches;
  final bool qrMenuEnabled;

  /// Filled in Super Admin once the products exist in Play Console.
  final String? googlePlayProductId;
  final String? googlePlayMonthlyBasePlanId;
  final String? googlePlayYearlyBasePlanId;

  double priceFor(BillingPeriod period) =>
      period == BillingPeriod.monthly ? monthlyPrice : yearlyPrice;

  String? basePlanIdFor(BillingPeriod period) => period == BillingPeriod.monthly
      ? googlePlayMonthlyBasePlanId
      : googlePlayYearlyBasePlanId;

  bool get isSellableOnPlay => googlePlayProductId != null;

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

/// Where the business's current access comes from (computed by
/// public.get_business_entitlement on the server).
enum AccessSource {
  appTrial,
  playTrial,
  playSubscription,
  manual,
  suspended,
  none,
}

AccessSource _accessSourceFromDb(String? value) => switch (value) {
  'APP_TRIAL' => AccessSource.appTrial,
  'PLAY_TRIAL' => AccessSource.playTrial,
  'PLAY_SUBSCRIPTION' => AccessSource.playSubscription,
  'MANUAL' => AccessSource.manual,
  'SUSPENDED' => AccessSource.suspended,
  _ => AccessSource.none,
};

/// The business's subscription state as the database sees it. Display
/// only -- opening orders, adding tables etc. is decided by database
/// triggers, and days left come from the server clock, not the device.
class Entitlement {
  const Entitlement({
    required this.status,
    required this.isOperational,
    required this.accessSource,
    required this.appTrialDaysLeft,
    required this.subscribedPlanId,
    required this.subscribedPlanCode,
    required this.subscribedPlanName,
    required this.effectivePlanName,
    required this.maxTables,
    required this.maxWaiters,
    required this.maxAreas,
    required this.playProductId,
    required this.playBasePlanId,
    required this.playExpiryTime,
    required this.playAutoRenewing,
    this.tableCount = 0,
    this.waiterCount = 0,
    this.areaCount = 0,
  });

  factory Entitlement.fromRow(
    Map<String, dynamic> row, {
    int tableCount = 0,
    int waiterCount = 0,
    int areaCount = 0,
  }) {
    final expiry = row['play_expiry_time'] as String?;
    return Entitlement(
      status: row['subscription_status'] as String,
      isOperational: row['is_operational'] as bool? ?? false,
      accessSource: _accessSourceFromDb(row['access_source'] as String?),
      appTrialDaysLeft: row['app_trial_days_left'] as int?,
      subscribedPlanId: row['subscribed_plan_id'] as String?,
      subscribedPlanCode: row['subscribed_plan_code'] as String?,
      subscribedPlanName: row['subscribed_plan_name'] as String?,
      effectivePlanName: row['effective_plan_name'] as String?,
      maxTables: row['max_tables'] as int?,
      maxWaiters: row['max_waiters'] as int?,
      maxAreas: row['max_areas'] as int?,
      playProductId: row['play_product_id'] as String?,
      playBasePlanId: row['play_base_plan_id'] as String?,
      playExpiryTime: expiry == null ? null : DateTime.parse(expiry),
      playAutoRenewing: row['play_auto_renewing'] as bool?,
      tableCount: tableCount,
      waiterCount: waiterCount,
      areaCount: areaCount,
    );
  }

  final String status;
  final bool isOperational;
  final AccessSource accessSource;
  final int? appTrialDaysLeft;
  final String? subscribedPlanId;
  final String? subscribedPlanCode;
  final String? subscribedPlanName;

  /// Plan whose rights apply now (top plan during free periods).
  final String? effectivePlanName;
  final int? maxTables;
  final int? maxWaiters;
  final int? maxAreas;
  final String? playProductId;
  final String? playBasePlanId;
  final DateTime? playExpiryTime;
  final bool? playAutoRenewing;
  final int tableCount;
  final int waiterCount;
  final int areaCount;

  bool get hasPlaySubscription =>
      isOperational &&
      (accessSource == AccessSource.playTrial ||
          accessSource == AccessSource.playSubscription);

  bool get isFreePeriod =>
      accessSource == AccessSource.appTrial ||
      accessSource == AccessSource.playTrial;

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
