import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models.dart';

/// Reads the plan catalog and the business's entitlement. Nothing here
/// writes: the subscription only changes through the server-side Google
/// Play verification (/api/play/verify, RTDN) or the platform admin.
class SubscriptionRepository {
  SubscriptionRepository(this._client);

  final SupabaseClient _client;

  Future<List<CatalogPlan>> fetchCatalog() async {
    final rows = await _client
        .from('plans')
        .select(
          'id, code, name, sort_order, monthly_price, yearly_price, '
          'yearly_discount, max_tables, max_waiters, max_areas, max_branches, '
          'qr_menu_enabled, google_play_product_id, '
          'google_play_monthly_base_plan_id, google_play_yearly_base_plan_id',
        )
        .eq('active', true)
        .not('code', 'is', null)
        .order('sort_order');
    return rows.map(CatalogPlan.fromRow).toList();
  }

  Future<Entitlement?> fetchEntitlement(String businessId) async {
    final results = await Future.wait<dynamic>([
      _client.rpc(
        'get_business_entitlement',
        params: {'p_business_id': businessId},
      ),
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
    ]);

    final rows = (results[0] as List<dynamic>?) ?? const [];
    if (rows.isEmpty) return null;
    return Entitlement.fromRow(
      rows.first as Map<String, dynamic>,
      tableCount: (results[1] as PostgrestResponse).count,
      waiterCount: (results[2] as PostgrestResponse).count,
      areaCount: (results[3] as PostgrestResponse).count,
    );
  }
}
