import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';

enum AppRole { platformAdmin, businessAdmin, cashier, waiter, kitchen, none }

class RoleContext {
  const RoleContext({required this.role, this.businessId, this.businessName});

  final AppRole role;
  final String? businessId;
  final String? businessName;
}

AppRole _roleFromDbValue(String value) {
  switch (value) {
    case 'BUSINESS_ADMIN':
      return AppRole.businessAdmin;
    case 'CASHIER':
      return AppRole.cashier;
    case 'WAITER':
      return AppRole.waiter;
    case 'KITCHEN':
      return AppRole.kitchen;
    default:
      return AppRole.none;
  }
}

/// Resolves who the signed-in user is for routing purposes. Always
/// re-reads from Supabase (subject to RLS) rather than trusting any
/// locally cached role -- mirrors getSessionContext /
/// getBusinessAdminContext in the web app for the same reason: the
/// client must never be the source of truth for authorization.
///
/// A user could in principle hold more than one active business
/// membership (multi-tenant staff, per the architecture doc); until
/// that's a real scenario we just take the first active one, same
/// simplification the web app makes.
final roleContextProvider = FutureProvider<RoleContext>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const RoleContext(role: AppRole.none);

  final client = ref.watch(supabaseClientProvider);

  final platformAdminRow = await client
      .from('platform_admins')
      .select('user_id')
      .eq('user_id', user.id)
      .maybeSingle();

  if (platformAdminRow != null) {
    return const RoleContext(role: AppRole.platformAdmin);
  }

  final memberships = await client
      .from('business_memberships')
      .select('role, business_id, businesses(name)')
      .eq('user_id', user.id)
      .eq('active', true)
      .limit(1);

  if (memberships.isEmpty) return const RoleContext(role: AppRole.none);

  final row = memberships.first;
  final businessRow = row['businesses'] as Map<String, dynamic>?;

  return RoleContext(
    role: _roleFromDbValue(row['role'] as String),
    businessId: row['business_id'] as String,
    businessName: businessRow?['name'] as String?,
  );
});
