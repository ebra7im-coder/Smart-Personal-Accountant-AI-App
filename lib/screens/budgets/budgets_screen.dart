// Budgets screen: current-month budgets with progress bars,
// add/edit sheet per category, 80%/100% alerts (engine in BudgetActions).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../models/budget.dart';
import '../../providers/budget_provider.dart';
import '../../providers/plan_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/budget_progress.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pro_badge.dart';
import '../paywall/paywall_screen.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Budget> budgets = ref.watch(activeBudgetsProvider);
    final BudgetActions actions = ref.watch(budgetActionsProvider);
    final bool isPro = ref.watch(isProProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('الميزانيات'),
        backgroundColor: AppColors.bg,
        actions: <Widget>[
          IconButton(
            onPressed: () => _showBudgetSheet(context, ref),
            icon: const Icon(Icons.add_circle_rounded, color: AppColors.green),
          ),
        ],
      ),
      body: budgets.isEmpty
          ? EmptyState(
              icon: Icons.savings_outlined,
              title: 'حدد ميزانيتك الشهرية',
              subtitle:
                  'مثلاً: ٢٠٠٠ جنيه للمطاعم — والتطبيق ينبّهك عند ٨٠٪ وعند التجاوز',
              actionLabel: 'إضافة ميزانية',
              onAction: () => _showBudgetSheet(context, ref),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                if (!isPro) ...<Widget>[
                  GestureDetector(
                    onTap: () => Navigator.of(context)
                        .pushNamed(PaywallScreen.routeName),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(AppSizes.radiusM),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: const Row(
                        children: <Widget>[
                          Icon(Icons.notifications_active_outlined,
                              size: 18, color: AppColors.warning),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'تنبيهات الميزانية تعمل حتى بدون نت — جرّبها مجاناً',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textGrey),
                            ),
                          ),
                          ProBadge(small: true),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                ...budgets.map((Budget b) {
                  final double spent = actions.spentFor(b.category);
                  return BudgetProgressCard(
                    budget: b,
                    spent: spent,
                    onEdit: () => _showBudgetSheet(
                      context,
                      ref,
                      existing: b,
                      currentSpent: spent,
                    ),
                    onDelete: () async {
                      await actions.remove(b.category, b.monthKey);
                      Fluttertoast.showToast(msg: 'تم حذف الميزانية');
                    },
                  );
                }),
              ],
            ),
    );
  }

  void _showBudgetSheet(
    BuildContext context,
    WidgetRef ref, {
    Budget? existing,
    double currentSpent = 0,
  }) {
    final TextEditingController limitCtrl = TextEditingController(
      text: existing?.limit.toStringAsFixed(0) ?? '',
    );
    String category = existing?.category ?? 'food';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, void Function(void Function()) setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      existing == null
                          ? 'ميزانية ${Helpers.monthName(DateTime.now())}'
                          : 'تعديل ميزانية ${category.arLabel}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 100,
                      child: GridView.builder(
                        scrollDirection: Axis.horizontal,
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 90,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1.1,
                        ),
                        itemCount: CategoryX.expenseKeys.length,
                        itemBuilder: (_, int i) {
                          final String key = CategoryX.expenseKeys[i];
                          final bool selected = key == category;
                          return GestureDetector(
                            onTap: () => setSheet(() => category = key),
                            child: Container(
                              decoration: BoxDecoration(
                                color: selected
                                    ? key.color.withOpacity(0.15)
                                    : AppColors.bg,
                                borderRadius:
                                    BorderRadius.circular(AppSizes.radiusM),
                                border: Border.all(
                                  color: selected
                                      ? key.color
                                      : Colors.transparent,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Icon(key.icon,
                                      size: 22,
                                      color: selected
                                          ? key.color
                                          : AppColors.textHint),
                                  const SizedBox(height: 4),
                                  Text(
                                    key.arLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      color: selected
                                          ? AppColors.textDark
                                          : AppColors.textHint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: limitCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Tajawal'),
                      decoration: InputDecoration(
                        hintText: 'المبلغ الشهري',
                        suffixText: 'ج.م',
                        filled: true,
                        fillColor: AppColors.bg,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusL),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: AppSizes.buttonH,
                      child: ElevatedButton(
                        onPressed: () async {
                          final double? limit =
                              double.tryParse(limitCtrl.text);
                          if (limit == null || limit <= 0) {
                            Fluttertoast.showToast(
                                msg: 'أدخل مبلغ الميزانية');
                            return;
                          }
                          final Budget budget = Budget(
                            category: category,
                            limit: limit,
                            monthKey: Helpers.monthKey(DateTime.now()),
                          );
                          await ref
                              .read(budgetActionsProvider)
                              .save(budget);
                          await ref
                              .read(budgetActionsProvider)
                              .checkThresholds();
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          Fluttertoast.showToast(
                              msg: 'تم حفظ الميزانية ✅');
                        },
                        child: const Text('حفظ الميزانية'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
