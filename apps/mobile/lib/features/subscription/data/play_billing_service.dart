import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../domain/play_offers.dart';

enum PlanChangeDirection { upgrade, downgrade }

class BillingUnavailableException implements Exception {
  const BillingUnavailableException();
}

/// Thin wrapper over Google Play Billing (in_app_purchase). Product ids
/// come from the `plans` table; offers, prices and campaign phases come
/// from Play. Purchases are never treated as successful here -- the
/// caller sends the token to /api/play/verify and waits for the server.
class PlayBillingService {
  PlayBillingService([InAppPurchase? iap])
    : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;
  final Map<String, GooglePlayProductDetails> _detailsByOfferToken = {};

  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  Future<bool> isAvailable() => _iap.isAvailable();

  /// productId -> every offer Play returns for this user (base plans and
  /// the campaign offers they're eligible for).
  Future<Map<String, List<PlayPlanOffer>>> loadOffers(
    Set<String> productIds,
  ) async {
    if (productIds.isEmpty) return const {};
    if (!await _iap.isAvailable()) throw const BillingUnavailableException();

    final response = await _iap.queryProductDetails(productIds);
    if (response.error != null) throw const BillingUnavailableException();

    _detailsByOfferToken.clear();
    final offers = <String, List<PlayPlanOffer>>{};
    for (final details in response.productDetails) {
      if (details is! GooglePlayProductDetails) continue;
      final index = details.subscriptionIndex;
      final offerDetails = details.productDetails.subscriptionOfferDetails;
      if (index == null || offerDetails == null) continue;
      final offer = offerDetails[index];
      _detailsByOfferToken[offer.offerIdToken] = details;
      offers
          .putIfAbsent(details.id, () => [])
          .add(
            PlayPlanOffer(
              productId: details.id,
              basePlanId: offer.basePlanId,
              offerId: offer.offerId,
              offerToken: offer.offerIdToken,
              phases: [
                for (final phase in offer.pricingPhases)
                  PlayPricingPhase(
                    priceMicros: phase.priceAmountMicros,
                    formattedPrice: phase.formattedPrice,
                    currencyCode: phase.priceCurrencyCode,
                    billingPeriod: phase.billingPeriod,
                    billingCycleCount: phase.billingCycleCount,
                    isInfinite:
                        phase.recurrenceMode ==
                        RecurrenceMode.infiniteRecurring,
                  ),
              ],
            ),
          );
    }
    return offers;
  }

  /// The subscription purchase currently owned by the Google account on
  /// this device, if it is one of ours. Needed to upgrade/downgrade.
  Future<GooglePlayPurchaseDetails?> findOwnedSubscription(
    Set<String> productIds,
  ) async {
    final addition = _iap
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final response = await addition.queryPastPurchases();
    for (final purchase in response.pastPurchases) {
      if (purchase.status == PurchaseStatus.purchased &&
          productIds.contains(purchase.productID)) {
        return purchase;
      }
    }
    return null;
  }

  /// Starts the Play purchase sheet. [businessId] becomes the purchase's
  /// obfuscatedAccountId; the server only accepts the token for that
  /// business. For a plan change pass [replacing] so Play replaces the
  /// old subscription instead of creating a second one.
  Future<void> launchPurchase({
    required PlayPlanOffer offer,
    required String businessId,
    GooglePlayPurchaseDetails? replacing,
    PlanChangeDirection? direction,
  }) async {
    final details = _detailsByOfferToken[offer.offerToken];
    if (details == null) throw const BillingUnavailableException();

    final param = GooglePlayPurchaseParam(
      productDetails: details,
      applicationUserName: businessId,
      offerToken: offer.offerToken,
      changeSubscriptionParam: replacing == null
          ? null
          : ChangeSubscriptionParam(
              oldPurchaseDetails: replacing,
              // Upgrade: switch now, remaining time credited.
              // Downgrade: takes effect at the next renewal.
              replacementMode: direction == PlanChangeDirection.downgrade
                  ? ReplacementMode.deferred
                  : ReplacementMode.withTimeProration,
            ),
    );
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  /// Re-delivers owned purchases on the purchase stream so any purchase
  /// whose server verification didn't finish (network loss, app killed)
  /// is verified again. Verification is idempotent on the server.
  Future<void> restorePurchases() => _iap.restorePurchases();
}
