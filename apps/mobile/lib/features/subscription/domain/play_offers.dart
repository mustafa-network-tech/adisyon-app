/// Google Play subscription offers as Play returns them. Nothing in here
/// knows campaign lengths or prices: a "15 gün ücretsiz" label is built
/// from the pricing phases Play sends for this user, so changing the
/// campaign in Play Console never needs an app update.
class PlayPricingPhase {
  const PlayPricingPhase({
    required this.priceMicros,
    required this.formattedPrice,
    required this.currencyCode,
    required this.billingPeriod,
    required this.billingCycleCount,
    required this.isInfinite,
  });

  final int priceMicros;
  final String formattedPrice;
  final String currencyCode;

  /// ISO 8601 duration, e.g. P15D, P2W, P1M, P1Y.
  final String billingPeriod;
  final int billingCycleCount;
  final bool isInfinite;

  bool get isFree => priceMicros == 0;
}

class PlayPlanOffer {
  const PlayPlanOffer({
    required this.productId,
    required this.basePlanId,
    required this.offerId,
    required this.offerToken,
    required this.phases,
  });

  final String productId;
  final String basePlanId;

  /// Null for the plain base plan (no campaign).
  final String? offerId;
  final String offerToken;
  final List<PlayPricingPhase> phases;

  PlayPricingPhase? get freePhase {
    for (final phase in phases) {
      if (phase.isFree) return phase;
    }
    return null;
  }

  /// The price the subscription renews at after any campaign phases.
  PlayPricingPhase get recurringPhase =>
      phases.lastWhere((phase) => phase.isInfinite, orElse: () => phases.last);

  bool get hasFreeTrial => freePhase != null;
}

final _isoPeriod = RegExp(r'^P(\d+)([DWMY])$');

/// "P15D" x1 -> "15 gün", "P1W" x2 -> "2 hafta", "P1M" -> "1 ay".
String describeIsoPeriod(String iso, {int cycles = 1}) {
  final match = _isoPeriod.firstMatch(iso);
  if (match == null) return iso;
  final amount = int.parse(match.group(1)!) * (cycles < 1 ? 1 : cycles);
  final unit = switch (match.group(2)) {
    'D' => 'gün',
    'W' => 'hafta',
    'M' => 'ay',
    _ => 'yıl',
  };
  return '$amount $unit';
}

/// "P1M" -> "ay", "P1Y" -> "yıl", "P3M" -> "3 ay".
String describeBillingUnit(String iso) {
  final match = _isoPeriod.firstMatch(iso);
  if (match == null) return iso;
  final amount = int.parse(match.group(1)!);
  final period = describeIsoPeriod(iso);
  return amount == 1 ? period.substring(2) : period;
}

/// "15 gün ücretsiz, ardından ₺399,00/ay" or "₺399,00/ay".
String describeOffer(PlayPlanOffer offer) {
  final recurring = offer.recurringPhase;
  final price =
      '${recurring.formattedPrice}/${describeBillingUnit(recurring.billingPeriod)}';
  final free = offer.freePhase;
  if (free == null) return price;
  final freeLength = describeIsoPeriod(
    free.billingPeriod,
    cycles: free.billingCycleCount,
  );
  return '$freeLength ücretsiz, ardından $price';
}

/// Picks the offer to show/buy for one base plan. Play only returns the
/// offers this Google account is eligible for, so an offer with a free
/// phase in the list is one the user may actually get. Plan changes
/// never use a campaign offer (no second free trial by switching plans).
PlayPlanOffer? selectOffer(
  List<PlayPlanOffer> offers, {
  required bool allowCampaign,
}) {
  if (offers.isEmpty) return null;
  final basePlanOnly = offers.where((offer) => offer.offerId == null);
  if (!allowCampaign) {
    return basePlanOnly.isEmpty ? null : basePlanOnly.first;
  }
  final withFreeTrial = offers.where((offer) => offer.hasFreeTrial);
  if (withFreeTrial.isNotEmpty) return withFreeTrial.first;
  return basePlanOnly.isEmpty ? offers.first : basePlanOnly.first;
}
