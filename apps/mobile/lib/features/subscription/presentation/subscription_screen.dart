import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency.dart';
import '../application/subscription_providers.dart';
import '../domain/models.dart';

/// Plan catalog + the business's own subscription state, for
/// BUSINESS_ADMIN only.
///
/// Google Play Billing is NOT wired up yet: there is no purchase flow and
/// nothing here can change the plan. When billing is added, the purchase
/// button launches the Play flow with the plan's product/base plan from
/// the `plans` table, shows Play's localized price instead of the list
/// price, and sends the purchase token to the server-side verification
/// job -- the subscription only changes once that job has verified it
/// (see docs/GOOGLE_PLAY_BILLING.md).
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(planCatalogProvider);
    final subscriptionAsync = ref.watch(businessSubscriptionProvider);

    Future<void> refresh() async {
      ref.invalidate(planCatalogProvider);
      ref.invalidate(businessSubscriptionProvider);
      await ref.read(planCatalogProvider.future);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Abonelik')),
      body: catalogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(onRetry: refresh),
        data: (plans) => RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              subscriptionAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => const _Notice(
                  text: 'Abonelik durumu şu an yüklenemedi.',
                  tone: _NoticeTone.warning,
                ),
                data: (subscription) => subscription == null
                    ? const SizedBox.shrink()
                    : _StatusSection(subscription: subscription),
              ),
              const SizedBox(height: 24),
              Text(
                'Planlar',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _PeriodToggle(plans: plans),
              const SizedBox(height: 16),
              _PlanCards(
                plans: plans,
                currentPlanId: subscriptionAsync.value?.planId,
              ),
              const SizedBox(height: 16),
              const _Notice(
                text:
                    'Google Play ile abonelik satın alma henüz etkin değil. '
                    'Satın alma açıldığında, ödeme sırasında Google Play\'in '
                    'gösterdiği fiyat geçerli olacaktır.',
                tone: _NoticeTone.info,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusSection extends StatelessWidget {
  const _StatusSection({required this.subscription});

  final BusinessSubscription subscription;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600);
    final now = DateTime.now();

    String? detail;
    if (subscription.isTrial) {
      final daysLeft = subscription.trialDaysLeft(now);
      detail = daysLeft > 0
          ? 'Denemenin bitmesine $daysLeft gün kaldı. Deneme süresince '
                'limitler uygulanmaz.'
          : 'Deneme süreniz doldu. Yeni adisyon açılamaz; açık '
                'adisyonları kapatabilirsiniz. Verileriniz silinmez.';
    } else if (subscription.status == 'GRACE_PERIOD') {
      detail =
          'Google Play ödemenizi alamadı. Erişiminiz şimdilik devam ediyor; '
          'Google Play\'deki ödeme yönteminizi güncelleyin.';
    } else if (subscription.playExpiryTime != null) {
      final date = _formatDate(subscription.playExpiryTime!.toLocal());
      detail = subscription.playAutoRenewing == true
          ? 'Aboneliğiniz $date tarihinde yenilenecek.'
          : 'Otomatik yenileme kapalı. Aboneliğiniz $date tarihine kadar '
                'geçerli.';
    }

    final usage = [
      ('Masa', subscription.tableCount, subscription.maxTables),
      ('Garson', subscription.waiterCount, subscription.maxWaiters),
      ('Alan', subscription.areaCount, subscription.maxAreas),
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
              subscription.statusLabel,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Plan: ${subscription.planName ?? 'Plan atanmadı'}',
              style: muted,
            ),
            if (detail != null) ...[
              const SizedBox(height: 12),
              Text(detail, style: muted),
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
  const _PlanCards({required this.plans, required this.currentPlanId});

  final List<CatalogPlan> plans;
  final String? currentPlanId;

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
          isCurrent: plan.id == currentPlanId,
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

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.period,
    required this.isCurrent,
  });

  final CatalogPlan plan;
  final BillingPeriod period;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: Colors.grey.shade600,
    );
    final isYearly = period == BillingPeriod.yearly;

    return Card(
      margin: EdgeInsets.zero,
      shape: isCurrent
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
                if (isCurrent)
                  const Chip(
                    label: Text('Mevcut plan'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
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
            if (isYearly && plan.yearlyDiscount > 0) ...[
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(
                  style: muted,
                  children: [
                    TextSpan(
                      text: formatTl(plan.monthlyPrice * 12),
                      style: const TextStyle(
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    TextSpan(
                      text: '  %${plan.yearlyDiscount.round()} indirim',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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
            // Deliberately disabled until Play Billing + server-side
            // verification exist -- no simulated purchase.
            const OutlinedButton(onPressed: null, child: Text('Yakında')),
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
