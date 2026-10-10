// Dashboard (الشاشة الرئيسية) — redesigned:
//   • Greeting header + sync status chip
//   • Balance card (tap -> budgets) — overflow-safe on small screens
//   • Quick actions row (expense / income / voice / OCR) — <3 clicks flows
//   • Monthly fl_chart with daily-average footer
//   • Budget snapshot (top 3)
//   • AI saving tip with shimmer loading + manual refresh
//   • Recent transactions + free-plan banner ad
//
// Responsive: FittedBox on big numbers, Wrap-friendly rows, fluid paddings.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../models/budget.dart';
import '../../models/transaction.dart';
import '../../providers/home_tab_provider.dart';
import '../../providers/plan_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/ads_service.dart';
import '../../services/ai_service.dart';
import '../../services/hive_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/balance_card.dart';
import '../../widgets/budget_progress.dart';
import '../../widgets/chart_widget.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pro_badge.dart';
import '../../widgets/transaction_card.dart';
import '../add_transaction/add_transaction_sheet.dart';
import '../ocr/ocr_flow.dart';
import '../paywall/paywall_screen.dart';
import '../transactions/transactions_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _aiTip;
  bool _tipLoading = false;
  bool _tipFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAiTip());
  }

  Future<void> _loadAiTip() async {
    if (_tipLoading) return;
    setState(() {
      _tipLoading = true;
      _tipFailed = false;
    });
    try {
      final double income = ref.read(monthTotalsProvider).income;
      final double expense = ref.read(monthTotalsProvider).expense;
      final String tip = await AiService.instance
          .savingTip(monthIncome: income, monthExpense: expense)
          .timeout(const Duration(seconds: 25));
      if (mounted) setState(() => _aiTip = tip);
    } catch (_) {
      // AI disabled/offline — hide the card, show a subtle retry.
      if (mounted) setState(() => _tipFailed = true);
    } finally {
      if (mounted) setState(() => _tipLoading = false);
    }
  }

  void _goTab(int tab) => ref.read(homeTabIndexProvider.notifier).state = tab;

  String get _greeting {
    final int hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'صباح الخير ☀️';
    if (hour >= 12 && hour < 17) return 'طاب يومك 🌤️';
    return 'مساء الخير 🌙';
  }

  @override
  Widget build(BuildContext context) {
    final double income = ref.watch(monthTotalsProvider).income;
    final double expense = ref.watch(monthTotalsProvider).expense;
    final double balance = income - expense;
    final Map<int, double> daily = ref.watch(dailyExpenseChartProvider);
    final int daysInMonth = ref.watch(daysInCurrentMonthProvider);
    final List<Transaction> all = ref.watch(transactionListProvider);
    final List<Budget> budgets = ref.watch(activeBudgetsProvider);
    final bool isPro = ref.watch(isProProvider);

    final int unsynced = _unsyncedCount();
    final int dayOfMonth = DateTime.now().day;
    final double dailyAvg = dayOfMonth > 0 ? expense / dayOfMonth : expense;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: all.isEmpty
          ? RefreshIndicator(
              onRefresh: _loadAiTip,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: <Widget>[
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.75,
                    child: EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'أهلاً بك في المحاسب الذكي 👋',
                      subtitle:
                          'ابدأ بإضافة أول معاملة: اضغط زر الميكروفون وقول '
                          '«صرفت ٥٠ جنيه مطعم» أو أضفها يدوياً',
                      actionLabel: 'إضافة معاملة',
                      onAction: () =>
                          AddTransactionSheet.maybeShow(context, ref),
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAiTip,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  16 + MediaQuery.of(context).padding.bottom,
                ),
                children: <Widget>[
                  // ---------- 1) Greeting header ----------
                  _Header(
                    greeting: _greeting,
                    subtitle: Helpers.date(DateTime.now()),
                    unsynced: unsynced,
                    isPro: isPro,
                    onSyncTap: () => _goTab(HomeTab.settings),
                  ),
                  const SizedBox(height: 14),

                  // ---------- 2) Balance ----------
                  BalanceCard(
                    balance: balance,
                    income: income,
                    expense: expense,
                    onTap: () => _goTab(HomeTab.budgets),
                  ),
                  const SizedBox(height: 14),

                  // ---------- 3) Quick actions ----------
                  _QuickActions(
                    onExpense: () => AddTransactionSheet.maybeShowWithType(
                        context, ref, TxType.expense),
                    onIncome: () => AddTransactionSheet.maybeShowWithType(
                        context, ref, TxType.income),
                    onVoice: () => AddTransactionSheet.maybeShow(context, ref),
                    onScan: () => OcrFlow.start(context, ref),
                  ),
                  const SizedBox(height: 14),

                  // ---------- 4) PRO upsell (free users) ----------
                  if (!isPro) ...<Widget>[
                    ProUpsellBanner(
                      onTap: () => Navigator.of(context)
                          .pushNamed(PaywallScreen.routeName),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ---------- 5) Monthly chart ----------
                  _SectionCard(
                    title: 'نظرة شهرية',
                    action: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.greenSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        Helpers.monthName(DateTime.now()),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF00805F),
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        MonthlyBarChart(
                          dailyExpenses: daily,
                          daysInMonth: daysInMonth,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            _MiniStat(
                              icon: Icons.today_rounded,
                              label: 'المعدل اليومي',
                              value: Helpers.money(dailyAvg),
                            ),
                            const SizedBox(width: 10),
                            _MiniStat(
                              icon: Icons.receipt_rounded,
                              label: 'عدد المعاملات',
                              value: '${all.length}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ---------- 6) Budget snapshot ----------
                  if (budgets.isNotEmpty) ...<Widget>[
                    _SectionCard(
                      title: 'ميزانياتي',
                      action: TextButton(
                        onPressed: () => _goTab(HomeTab.budgets),
                        child:
                            const Text('إدارة', style: TextStyle(fontSize: 12)),
                      ),
                      child: Column(
                        children: budgets
                            .take(3)
                            .map((Budget b) => BudgetProgressCard(
                                  budget: b,
                                  spent: _spentFor(b),
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ---------- 7) AI tip ----------
                  if (_tipLoading)
                    const _TipShimmer()
                  else if (_aiTip != null)
                    _AiTipCard(tip: _aiTip!, onRefresh: _loadAiTip)
                  else if (_tipFailed)
                    _TipRetry(onRetry: _loadAiTip),

                  // ---------- 8) Recent transactions ----------
                  _SectionCard(
                    title: 'أحدث المعاملات',
                    action: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const TransactionsScreen()),
                      ),
                      child: const Text('عرض الكل',
                          style: TextStyle(fontSize: 12)),
                    ),
                    child: Column(
                      children: all
                          .take(6)
                          .map((Transaction t) => TransactionCard(
                                transaction: t,
                                onTap: () =>
                                    AddTransactionSheet.showWithPrefill(
                                  context,
                                  null,
                                  existing: t,
                                ),
                                onDelete: () => ref
                                    .read(transactionListProvider.notifier)
                                    .remove(t.id),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ---------- 9) Free-plan banner ad ----------
                  if (!isPro) ...<Widget>[
                    const Center(child: ProBadge()),
                    const SizedBox(height: 8),
                    AdsService.bannerAdWidget(),
                  ],
                ],
              ),
            ),
    );
  }

  int _unsyncedCount() {
    try {
      return HiveService.unsyncedIds().length;
    } catch (_) {
      return 0;
    }
  }

  double _spentFor(Budget b) {
    final String mk = Helpers.monthKey(DateTime.now());
    return ref
        .read(transactionListProvider)
        .where((Transaction t) =>
            t.type == TxType.expense &&
            t.category == b.category &&
            t.monthKey() == mk)
        .fold(0.0, (double s, Transaction t) => s + t.amount);
  }
}

// ===========================================================================
// Header
// ===========================================================================
class _Header extends StatelessWidget {
  const _Header({
    required this.greeting,
    required this.subtitle,
    required this.unsynced,
    required this.isPro,
    required this.onSyncTap,
  });

  final String greeting;
  final String subtitle;
  final int unsynced;
  final bool isPro;
  final VoidCallback onSyncTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: <Color>[AppColors.green, Color(0xFF00A97F)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.person_rounded,
              color: AppColors.white, size: 24),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      greeting,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  if (isPro) ...<Widget>[
                    const SizedBox(width: 6),
                    const ProBadge(small: true),
                  ],
                ],
              ),
              Text(
                subtitle,
                style:
                    const TextStyle(fontSize: 11.5, color: AppColors.textHint),
              ),
            ],
          ),
        ),
        if (unsynced > 0)
          Tooltip(
            message: '$unsynced معاملة في انتظار المزامنة',
            child: ActionChip(
              avatar: const Icon(Icons.cloud_upload_rounded,
                  size: 15, color: AppColors.warning),
              label: Text('$unsynced',
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.warning)),
              side: const BorderSide(color: AppColors.warning),
              backgroundColor: AppColors.white,
              onPressed: onSyncTap,
            ),
          ),
      ],
    );
  }
}

// ===========================================================================
// Quick actions — the <3-clicks entries
// ===========================================================================
class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onExpense,
    required this.onIncome,
    required this.onVoice,
    required this.onScan,
  });

  final VoidCallback onExpense;
  final VoidCallback onIncome;
  final VoidCallback onVoice;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _QuickAction(
            icon: Icons.arrow_upward_rounded,
            label: 'مصروف',
            color: AppColors.danger,
            onTap: onExpense,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickAction(
            icon: Icons.arrow_downward_rounded,
            label: 'دخل',
            color: AppColors.green,
            onTap: onIncome,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickAction(
            icon: Icons.mic_rounded,
            label: 'صوت',
            color: AppColors.navy,
            onTap: onVoice,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickAction(
            icon: Icons.document_scanner_outlined,
            label: 'فاتورة',
            color: const Color(0xFFF5A524),
            badge: const ProBadge(small: true),
            onTap: onScan,
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: color.withOpacity(0.12),
                    child: Icon(icon, size: 19, color: color),
                  ),
                  if (badge != null)
                    Positioned(top: -7, left: -7, child: badge!),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Section card + mini stat
// ===========================================================================
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.navy,
                ),
              ),
              const Spacer(),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 15, color: AppColors.textHint),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textHint)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// AI tip card + shimmer + retry
// ===========================================================================
class _AiTipCard extends StatelessWidget {
  const _AiTipCard({required this.tip, required this.onRefresh});

  final String tip;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: <Color>[Color(0xFFE0F9F1), Color(0xFFF0FDF9)],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.green.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.green,
            child: Icon(Icons.auto_awesome, size: 16, color: AppColors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'نصيحة محاسبك الآلي',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Color(0xFF00805F),
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  tip,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'نصيحة جديدة',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded,
                size: 18, color: Color(0xFF00805F)),
          ),
        ],
      ),
    );
  }
}

class _TipShimmer extends StatelessWidget {
  const _TipShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.line),
      ),
      child: Shimmer.fromColors(
        baseColor: AppColors.line,
        highlightColor: AppColors.bg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.line,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Container(width: 110, height: 12, color: AppColors.line),
              ],
            ),
            const SizedBox(height: 12),
            Container(
                width: double.infinity, height: 12, color: AppColors.line),
            const SizedBox(height: 6),
            FractionallySizedBox(
              widthFactor: 0.65,
              alignment: AlignmentDirectional.centerStart,
              child: Container(height: 12, color: AppColors.line),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipRetry extends StatelessWidget {
  const _TipRetry({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.tips_and_updates_outlined,
              size: 18, color: AppColors.textHint),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'نصيحة المحاسب الآلي غير متاحة الآن',
              style: TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('إعادة المحاولة', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
