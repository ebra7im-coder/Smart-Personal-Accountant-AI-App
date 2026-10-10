// A single transaction row: category avatar, title, date, signed amount.

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../models/transaction.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class TransactionCard extends StatelessWidget {
  const TransactionCard({
    super.key,
    required this.transaction,
    this.onTap,
    this.onDelete,
    this.showDate = true,
  });

  final Transaction transaction;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final bool isIncome = transaction.type == TxType.income;
    final String categoryKey = transaction.category;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Slidable(
        enabled: onDelete != null,
        endActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: 0.22,
          children: <Widget>[
            SlidableAction(
              onPressed: (_) => onDelete?.call(),
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.white,
              icon: Icons.delete_outline,
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
          ],
        ),
        child: Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: <Widget>[
                  // Category avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: categoryKey.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      categoryKey.icon,
                      color: categoryKey.color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title + meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          transaction.note.isNotEmpty
                              ? transaction.note
                              : categoryKey.arLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: <Widget>[
                            Text(
                              categoryKey.arLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textHint,
                              ),
                            ),
                            if (showDate) ...<Widget>[
                              const Text(' • ',
                                  style: TextStyle(
                                      color: AppColors.textHint, fontSize: 12)),
                              Text(
                                Helpers.smartDate(transaction.date),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textHint,
                                ),
                              ),
                            ],
                            if (transaction.source == 'voice')
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(Icons.mic,
                                    size: 12, color: AppColors.green),
                              ),
                            if (transaction.source == 'ocr')
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(Icons.document_scanner_outlined,
                                    size: 12, color: AppColors.info),
                              ),
                            if (!transaction.synced)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(Icons.cloud_off_outlined,
                                    size: 12, color: AppColors.warning),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Signed amount
                  Text(
                    Helpers.signed(transaction.type, transaction.amount),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: isIncome ? AppColors.green : AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
