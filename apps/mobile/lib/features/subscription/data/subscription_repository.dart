import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models.dart';

/// Reads the plan catalog and the business's subscription state. Nothing
/// here writes: plan changes only ever come from the server-side Google
/// Play verification job (or the platform admin), never from the app.
class SubscriptionRepository {
  SubscriptionRepository(this._client);

  final SupabaseClient _client;

  Future<List<CatalogPlan>> fetchCatalog() async {
    final rows = await _client
        .from('plans')
        .select(
          'id, code, name, monthly_price, yearly_price, yearly_discount, '
          'max_tables, max_waiters, max_areas, max_branches, qr_menu_enabled',
        )
        .eq('active', true)
        .not('code', 'is', null)
        .order('sort_order');
    return rows.map(CatalogPlan.fromRow).toList();
  }

  Future<BusinessSubscription> fetchBusinessSubscription(
    String businessId,
  ) async {
    final results = await Future.wait<dynamic>([
      _client
          .from('businesses')
          .select(
            'subscription_status, trial_ends_at, plan_id, '
            'plans(name, max_tables, max_waiters, max_areas)',
          )
          .eq('id', businessId)
          .single(),
      _client
          .from('restaurant_tables')
          .select('id')
          .eq('business_id', businessId)
          .eq('active', true)
          .count(CountOption.exact),
      _client
          .from('business_memberships')
          .select('id')
          .eq('business_id', businessId)
          .eq('active', true)
          .eq('role', 'WAITER')
          .count(CountOption.exact),
      _client
          .from('areas')
          .select('id')
          .eq('business_id', businessId)
          .eq('active', true)
          .count(CountOption.exact),
      _client.rpc(
        'get_own_business_subscription',
        params: {'p_business_id': businessId},
      ),
    ]);

    final business = results[0] as Map<String, dynamic>;
    final plan = business['plans'] as Map<String, dynamic>?;
    final playRows = (results[4] as List<dynamic>?) ?? const [];
    final play = playRows.isEmpty
        ? null
        : playRows.first as Map<String, dynamic>;
    final playExpiry = play?['expiry_time'] as String?;

    return BusinessSubscription(
      status: business['subscription_status'] as String,
      trialEndsAt: DateTime.parse(business['trial_ends_at'] as String),
      planId: business['plan_id'] as String?,
      planName: plan?['name'] as String?,
      maxTables: plan?['max_tables'] as int?,
      maxWaiters: plan?['max_waiters'] as int?,
      maxAreas: plan?['max_areas'] as int?,
      tableCount: (results[1] as PostgrestResponse).count,
      waiterCount: (results[2] as PostgrestResponse).count,
      areaCount: (results[3] as PostgrestResponse).count,
      playExpiryTime: playExpiry == null ? null : DateTime.parse(playExpiry),
      playAutoRenewing: play?['auto_renewing'] as bool?,
    );
  }
}
