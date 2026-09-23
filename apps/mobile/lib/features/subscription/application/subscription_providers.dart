import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../auth/application/auth_providers.dart';
import '../../auth/application/role_context.dart';
import '../data/play_billing_service.dart';
import '../data/purchase_verifier.dart';
import '../data/subscription_repository.dart';
import '../domain/models.dart';
import '../domain/play_offers.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(ref.watch(supabaseClientProvider));
});

final playBillingServiceProvider = Provider<PlayBillingService>((ref) {
  return PlayBillingService();
});

final purchaseVerifierProvider = Provider<PurchaseVerifier>((ref) {
  return const PurchaseVerifier();
});

final planCatalogProvider = FutureProvider.autoDispose<List<CatalogPlan>>((
  ref,
) {
  return ref.watch(subscriptionRepositoryProvider).fetchCatalog();
});

final entitlementProvider = FutureProvider.autoDispose<Entitlement?>((
  ref,
) async {
  final businessId = ref.watch(roleContextProvider).value?.businessId;
  if (businessId == null) return null;
  return ref.watch(subscriptionRepositoryProvider).fetchEntitlement(businessId);
});

final selectedBillingPeriodProvider = StateProvider.autoDispose<BillingPeriod>(
  (ref) => BillingPeriod.monthly,
);

/// Offers from Google Play, or null when purchasing isn't possible right
/// now (Play product ids not set in Super Admin yet, WEB_BASE_URL not
/// configured, Play Billing unavailable on the device). Null means the
/// screen shows "abonelik servisi henüz kullanılamıyor" -- never a fake
/// purchase path.
final playOffersProvider =
    FutureProvider.autoDispose<Map<String, List<PlayPlanOffer>>?>((ref) async {
      final plans = await ref.watch(planCatalogProvider.future);
      final productIds = {
        for (final plan in plans)
          if (plan.googlePlayProductId != null) plan.googlePlayProductId!,
      };
      if (productIds.isEmpty ||
          !ref.watch(purchaseVerifierProvider).isConfigured) {
        return null;
      }
      try {
        final offers = await ref
            .watch(playBillingServiceProvider)
            .loadOffers(productIds);
        return offers.isEmpty ? null : offers;
      } catch (_) {
        return null;
      }
    });

enum PurchaseFlowStatus { idle, launching, pending, verifying, success, error }

class PurchaseFlowState {
  const PurchaseFlowState(this.status, [this.message]);

  final PurchaseFlowStatus status;
  final String? message;

  bool get isBusy =>
      status == PurchaseFlowStatus.launching ||
      status == PurchaseFlowStatus.verifying;
}

String _verifyErrorMessage(String? code) => switch (code) {
  'ACCOUNT_MISMATCH' || 'TOKEN_OWNED_BY_OTHER_BUSINESS' =>
    'Bu Google Play aboneliği başka bir işletmeye ait.',
  'NOT_BUSINESS_ADMIN' => 'Aboneliği yalnızca işletme yöneticisi başlatabilir.',
  'UNKNOWN_PLAY_PRODUCT' => 'Bu abonelik ürünü bir planla eşleşmiyor.',
  'INVALID_PURCHASE' => 'Satın alma Google Play tarafından doğrulanamadı.',
  _ =>
    'Satın alma alındı ancak henüz doğrulanamadı. Uygulamayı daha sonra '
        'tekrar açtığınızda otomatik olarak yeniden denenecek.',
};

/// Listens to Google Play purchase updates and hands every purchase to
/// the server for verification. The subscription is shown as active only
/// after the server has verified it with Google and the entitlement is
/// re-read from the database.
class PurchaseController extends Notifier<PurchaseFlowState> {
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _userInitiated = false;

  @override
  PurchaseFlowState build() {
    final service = ref.watch(playBillingServiceProvider);
    _subscription = service.purchaseStream.listen(
      _onPurchases,
      onError: (_) => state = const PurchaseFlowState(
        PurchaseFlowStatus.error,
        'Google Play ile bağlantı kurulamadı.',
      ),
    );
    ref.onDispose(() => _subscription?.cancel());
    // Re-verify purchases that were made but not confirmed earlier.
    unawaited(service.restorePurchases().catchError((_) {}));
    return const PurchaseFlowState(PurchaseFlowStatus.idle);
  }

  Future<void> buy({
    required CatalogPlan plan,
    required PlayPlanOffer offer,
    required Entitlement? entitlement,
    required List<CatalogPlan> catalog,
  }) async {
    final role = ref.read(roleContextProvider).value;
    if (role?.role != AppRole.businessAdmin || role?.businessId == null) {
      state = const PurchaseFlowState(
        PurchaseFlowStatus.error,
        'Aboneliği yalnızca işletme yöneticisi başlatabilir.',
      );
      return;
    }

    state = const PurchaseFlowState(PurchaseFlowStatus.launching);
    final service = ref.read(playBillingServiceProvider);
    try {
      final replacing = entitlement != null && entitlement.hasPlaySubscription
          ? await service.findOwnedSubscription({
              for (final p in catalog)
                if (p.googlePlayProductId != null) p.googlePlayProductId!,
            })
          : null;
      if (entitlement != null &&
          entitlement.hasPlaySubscription &&
          replacing == null) {
        state = const PurchaseFlowState(
          PurchaseFlowStatus.error,
          'Mevcut aboneliğiniz bu cihazdaki Google hesabında bulunamadı. '
          'Aboneliği satın alan Google hesabıyla giriş yapın veya '
          '"Aboneliği Yönet" üzerinden değiştirin.',
        );
        return;
      }
      PlanChangeDirection? direction;
      if (replacing != null) {
        final current = catalog
            .where((p) => p.code == entitlement!.subscribedPlanCode)
            .firstOrNull;
        direction = current != null && plan.sortOrder < current.sortOrder
            ? PlanChangeDirection.downgrade
            : PlanChangeDirection.upgrade;
      }

      _userInitiated = true;
      await service.launchPurchase(
        offer: offer,
        businessId: role!.businessId!,
        replacing: replacing,
        direction: direction,
      );
    } catch (_) {
      _userInitiated = false;
      state = const PurchaseFlowState(
        PurchaseFlowStatus.error,
        'Google Play satın alma ekranı açılamadı.',
      );
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          state = const PurchaseFlowState(
            PurchaseFlowStatus.pending,
            'Ödeme Google Play tarafından işleniyor.',
          );
        case PurchaseStatus.canceled:
          _userInitiated = false;
          state = const PurchaseFlowState(PurchaseFlowStatus.idle);
        case PurchaseStatus.error:
          _userInitiated = false;
          state = const PurchaseFlowState(
            PurchaseFlowStatus.error,
            'Satın alma tamamlanamadı.',
          );
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verify(purchase);
      }
    }
  }

  Future<void> _verify(PurchaseDetails purchase) async {
    final userInitiated =
        _userInitiated && purchase.status == PurchaseStatus.purchased;
    final accessToken = ref
        .read(supabaseClientProvider)
        .auth
        .currentSession
        ?.accessToken;
    if (accessToken == null) return;

    if (userInitiated) {
      state = const PurchaseFlowState(PurchaseFlowStatus.verifying);
    }
    final result = await ref
        .read(purchaseVerifierProvider)
        .verify(
          purchaseToken: purchase.verificationData.serverVerificationData,
          accessToken: accessToken,
        );

    if (result.ok) {
      ref.invalidate(entitlementProvider);
      ref.invalidate(playOffersProvider);
      if (userInitiated) {
        _userInitiated = false;
        state = const PurchaseFlowState(
          PurchaseFlowStatus.success,
          'Aboneliğiniz doğrulandı.',
        );
      }
    } else if (userInitiated) {
      _userInitiated = false;
      state = PurchaseFlowState(
        PurchaseFlowStatus.error,
        _verifyErrorMessage(result.errorCode),
      );
    }
  }

  void dismissMessage() {
    state = const PurchaseFlowState(PurchaseFlowStatus.idle);
  }
}

final purchaseControllerProvider =
    NotifierProvider<PurchaseController, PurchaseFlowState>(
      PurchaseController.new,
    );
