import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../auth/application/auth_providers.dart';
import '../../auth/application/role_context.dart';
import '../data/subscription_repository.dart';
import '../domain/models.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(ref.watch(supabaseClientProvider));
});

final planCatalogProvider = FutureProvider.autoDispose<List<CatalogPlan>>((
  ref,
) {
  return ref.watch(subscriptionRepositoryProvider).fetchCatalog();
});

final businessSubscriptionProvider =
    FutureProvider.autoDispose<BusinessSubscription?>((ref) async {
      final businessId = ref.watch(roleContextProvider).value?.businessId;
      if (businessId == null) return null;
      return ref
          .watch(subscriptionRepositoryProvider)
          .fetchBusinessSubscription(businessId);
    });

final selectedBillingPeriodProvider = StateProvider.autoDispose<BillingPeriod>(
  (ref) => BillingPeriod.monthly,
);
