// Budget card: category icon, spent/limit, animated progress bar,
// 80% warning + 100% exceeded visual states.

import 'package:flutter/material.dart';

import '../models/budget.dart';
import '../models/budget_status.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class BudgetProgressCard extends StatelessWidget {
  const BudgetProgressCard({
    super.key,
    required this.budget,
    required this.spent,
    this.onEdit,
    this.onDelete,
  });

  final Budget budget;
  final double spent;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final BudgetStatus status = budget.statusFor(spent);
    final double progress = budget.progressFor(spent);
    final Color barColor = switch (status) {
      BudgetStatus.exceeded => AppColors.danger,
      BudgetStatus.warning => AppColors.warning,
      BudgetStatus.none => AppColors.green,
    };
    final String categoryKey = budget.category;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: categoryKey.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(categoryKey.icon, size: 20, color: categoryKey.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  categoryKey.arLabel,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              if (status == BudgetStatus.warning)
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.warning, size: 18),
              if (status == BudgetStatus.exceeded)
                const Icon(Icons.error_outline,
                    color: AppColors.danger, size: 18),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined,
                    size: 18, color: AppColors.textHint),
                onPressed: onEdit,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: AppColors.textHint),
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (BuildContext ctx, double v, _) =>
                  LinearProgressIndicator(
                value: v,
                minHeight: 10,
                backgroundColor: AppColors.bg,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'صرفت ${Helpers.money(spent)} من ${Helpers.money(budget.limit)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}٪',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: barColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
