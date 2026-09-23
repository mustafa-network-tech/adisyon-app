import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/utils/currency.dart';
import '../application/subscription_providers.dart';
import '../domain/models.dart';
import '../domain/play_offers.dart';

/// Plan catalog, the business's entitlement and Google Play purchasing,
/// for BUSINESS_ADMIN only. Prices and campaign text come from Google
/// Play; the subscription only changes after the server verified the
/// purchase with Google (see PurchaseController).
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(planCatalogProvider);
    final entitlementAsync = ref.watch(entitlementProvider);
    final offersAsync = ref.watch(playOffersProvider);

    ref.listen(purchaseControllerProvider, (previous, next) {
      final message = next.message;
      if (message == null || previous?.message == message) return;
      if (next.status == PurchaseFlowStatus.success ||
          next.status == PurchaseFlowStatus.error ||
          next.status == PurchaseFlowStatus.pending) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });

    Future<void> refresh() async {
      ref.invalidate(planCatalogProvider);
      ref.invalidate(entitlementProvider);
      ref.invalidate(playOffersProvider);
      await ref.read(planCatalogProvider.future);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Abonelik')),
      body: catalogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(onRetry: refresh),
        data: (plans) {
          final entitlement = entitlementAsync.value;
          final offers = offersAsync.value;
          final offersLoading = offersAsync.isLoading;
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                entitlementAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => const _Notice(
                    text: 'Abonelik durumu şu an yüklenemedi.',
                    tone: _NoticeTone.warning,
                  ),
                  data: (value) => value == null
                      ? const SizedBox.shrink()
                      : _StatusSection(entitlement: value),
                ),
                const SizedBox(height: 24),
                Text(
                  'Planlar',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _PeriodToggle(plans: plans),
                const SizedBox(height: 16),
                if (!offersLoading && offers == null) ...[
                  const _Notice(
                    text:
                        'Abonelik servisi şu an kullanılamıyor. Planları '
                        'inceleyebilirsiniz; satın alma açıldığında burada '
                        'Google Play fiyatları görünecek.',
                    tone: _NoticeTone.warning,
                  ),
                  const SizedBox(height: 16),
                ],
                _PlanCards(
                  plans: plans,
                  entitlement: entitlement,
                  offers: offers,
                  offersLoading: offersLoading,
                ),
                const SizedBox(height: 16),
                const _Notice(
                  text:
                      'Abonelik Google Play üzerinden alınır ve siz iptal '
                      'edene kadar seçtiğiniz dönem sonunda otomatik yenilenir. '
                      'Ücretsiz dönem içeren bir teklifte, dönem bitmeden iptal '
                      'etmezseniz ücretli abonelik başlar. İptal ve ödeme '
                      'yöntemi: Google Play > Ödemeler ve abonelikler.',
                  tone: _NoticeTone.info,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusSection extends StatelessWidget {
  const _StatusSection({required this.entitlement});

  final Entitlement entitlement;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600);

    final detail = switch (entitlement.accessSource) {
      AccessSource.appTrial =>
        'Ücretsiz denemenizin ${entitlement.appTrialDaysLeft} günü kaldı. '
            'Deneme süresince ${entitlement.effectivePlanName} planının tüm '
            'özellikleri açık.',
      AccessSource.playTrial =>
        'Google Play ücretsiz döneminiz sürüyor'
            '${entitlement.playExpiryTime == null ? '' : ' (${_formatDate(entitlement.playExpiryTime!.toLocal())} tarihine kadar)'}. '
            'Bu süre boyunca ${entitlement.effectivePlanName} planının tüm '
            'özellikleri açık.',
      AccessSource.playSubscription =>
        entitlement.playExpiryTime == null
            ? null
            : entitlement.playAutoRenewing == true
            ? 'Aboneliğiniz ${_formatDate(entitlement.playExpiryTime!.toLocal())} tarihinde yenilenecek.'
            : 'Otomatik yenileme kapalı. Aboneliğiniz '
                  '${_formatDate(entitlement.playExpiryTime!.toLocal())} tarihine kadar geçerli.',
      AccessSource.suspended =>
        'Hesabınız askıya alındı. Lütfen destek ile iletişime geçin.',
      AccessSource.none =>
        'Aktif bir deneme veya aboneliğiniz yok. Yeni adisyon açılamaz; açık '
            'adisyonları kapatabilirsiniz ve verileriniz silinmez. Devam etmek '
            'için aşağıdan bir plan seçin.',
      AccessSource.manual => null,
    };

    final usage = [
      ('Masa', entitlement.tableCount, entitlement.maxTables),
      ('Garson', entitlement.waiterCount, entitlement.maxWaiters),
      ('Alan', entitlement.areaCount, entitlement.maxAreas),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Durum', style: muted),
            const SizedBox(height: 4),
            Text(
              entitlement.statusLabel,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Abone olunan plan: ${entitlement.subscribedPlanName ?? '—'}',
              style: muted,
            ),
            Text(
              'Şu an geçerli haklar: ${entitlement.effectivePlanName ?? '—'}',
              style: muted,
            ),
            if (entitlement.status == 'GRACE_PERIOD') ...[
              const SizedBox(height: 12),
              const _Notice(
                text:
                    'Google Play ödemenizi alamadı. Erişiminiz şimdilik devam '
                    'ediyor; Google Play\'deki ödeme yönteminizi güncelleyin.',
                tone: _NoticeTone.warning,
              ),
            ],
            if (detail != null) ...[
              const SizedBox(height: 12),
              Text(detail, style: muted),
            ],
            if (entitlement.playProductId != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () =>
                    _openManageSubscription(entitlement.playProductId!),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Aboneliği Yönet'),
              ),
            ],
            const Divider(height: 32),
            for (final (label, used, limit) in usage) ...[
              Row(
                children: [
                  Expanded(child: Text(label)),
                  Text(
                    '$used / ${limit ?? 'Sınırsız'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              if (limit != null && limit > 0) ...[
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (used / limit).clamp(0, 1).toDouble(),
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade200,
                    color: used >= limit
                        ? Colors.amber.shade700
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}.${two(date.month)}.${date.year}';
  }
}

Future<void> _openManageSubscription(String productId) async {
  final uri = Uri.https('play.google.com', '/store/account/subscriptions', {
    'sku': productId,
    'package': AppConfig.androidPackageName,
  });
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _PeriodToggle extends ConsumerWidget {
  const _PeriodToggle({required this.plans});

  final List<CatalogPlan> plans;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedBillingPeriodProvider);
    final discounts = plans.map((plan) => plan.yearlyDiscount).toSet();
    final sharedDiscount = discounts.length == 1 && discounts.first > 0
        ? discounts.first
        : null;

    return SegmentedButton<BillingPeriod>(
      segments: [
        const ButtonSegment(value: BillingPeriod.monthly, label: Text('Aylık')),
        ButtonSegment(
          value: BillingPeriod.yearly,
          label: Text(
            sharedDiscount == null
                ? 'Yıllık'
                : 'Yıllık (%${sharedDiscount.round()} indirim)',
          ),
        ),
      ],
      selected: {period},
      showSelectedIcon: false,
      onSelectionChanged: (selection) =>
          ref.read(selectedBillingPeriodProvider.notifier).state =
              selection.first,
    );
  }
}

class _PlanCards extends ConsumerWidget {
  const _PlanCards({
    required this.plans,
    required this.entitlement,
    required this.offers,
    required this.offersLoading,
  });

  final List<CatalogPlan> plans;
  final Entitlement? entitlement;
  final Map<String, List<PlayPlanOffer>>? offers;
  final bool offersLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedBillingPeriodProvider);

    if (plans.isEmpty) {
      return const _Notice(
        text: 'Planlar şu an görüntülenemiyor.',
        tone: _NoticeTone.warning,
      );
    }

    final cards = [
      for (final plan in plans)
        _PlanCard(
          plan: plan,
          period: period,
          entitlement: entitlement,
          catalog: plans,
          offers: offers,
          offersLoading: offersLoading,
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 720) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: cards[i]),
                ],
              ],
            ),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              cards[i],
            ],
          ],
        );
      },
    );
  }
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({
    required this.plan,
    required this.period,
    required this.entitlement,
    required this.catalog,
    required this.offers,
    required this.offersLoading,
  });

  final CatalogPlan plan;
  final BillingPeriod period;
  final Entitlement? entitlement;
  final List<CatalogPlan> catalog;
  final Map<String, List<PlayPlanOffer>>? offers;
  final bool offersLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: Colors.grey.shade600,
    );
    final isYearly = period == BillingPeriod.yearly;
    final purchase = ref.watch(purchaseControllerProvider);

    final basePlanId = plan.basePlanIdFor(period);
    final isPlanChange = entitlement?.hasPlaySubscription ?? false;
    final planOffers = [
      for (final offer
          in offers?[plan.googlePlayProductId] ?? const <PlayPlanOffer>[])
        if (offer.basePlanId == basePlanId) offer,
    ];
    final offer = selectOffer(planOffers, allowCampaign: !isPlanChange);

    final isSubscribedPlan = entitlement?.subscribedPlanId == plan.id;
    final isCurrentPurchase =
        isPlanChange &&
        isSubscribedPlan &&
        entitlement?.playBasePlanId == basePlanId;

    final String buttonLabel;
    VoidCallback? onPressed;
    if (isCurrentPurchase) {
      buttonLabel = 'Mevcut aboneliğiniz';
    } else if (offersLoading) {
      buttonLabel = 'Yükleniyor...';
    } else if (offer == null) {
      buttonLabel = 'Şu an kullanılamıyor';
    } else {
      buttonLabel = isPlanChange
          ? 'Bu plana geç'
          : offer.hasFreeTrial
          ? 'Ücretsiz dönemi başlat'
          : 'Aboneliği başlat';
      if (!purchase.isBusy) {
        onPressed = () => ref
            .read(purchaseControllerProvider.notifier)
            .buy(
              plan: plan,
              offer: offer,
              entitlement: entitlement,
              catalog: catalog,
            );
      }
    }

    return Card(
      margin: EdgeInsets.zero,
      shape: isSubscribedPlan
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isSubscribedPlan)
                  const Chip(
                    label: Text('Mevcut plan'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (offer != null)
              // Google Play's localized price and campaign, verbatim.
              Text(
                describeOffer(offer),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              )
            else ...[
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: formatTl(plan.priceFor(period)),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(text: isYearly ? ' / yıl' : ' / ay', style: muted),
                  ],
                ),
              ),
              Text('Liste fiyatı', style: muted),
            ],
            if (isYearly && plan.yearlyDiscount > 0) ...[
              const SizedBox(height: 2),
              Text(
                '%${plan.yearlyDiscount.round()} yıllık indirim',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            for (final feature in plan.features)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(feature)),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onPressed, child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}

enum _NoticeTone { info, warning }

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.tone});

  final String text;
  final _NoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final warning = tone == _NoticeTone.warning;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warning ? Colors.amber.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: warning ? Colors.amber.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: warning ? Colors.amber.shade900 : Colors.grey.shade700,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('Planlar yüklenemedi.'),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}
