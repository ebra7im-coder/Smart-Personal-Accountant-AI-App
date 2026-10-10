// Dashboard hero card: total balance + income/expense chips.

import 'package:flutter/material.dart';

import '../utils/constants.dart';
import '../utils/helpers.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.balance,
    required this.income,
    required this.expense,
    this.currency = 'ج.م',
    this.onTap,
  });

  final double balance;
  final double income;
  final double expense;
  final String currency;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: <Color>[AppColors.navy, Color(0xFF164080)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.navy.withOpacity(0.35),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.account_balance_wallet_rounded,
                    color: AppColors.green, size: 18),
                const SizedBox(width: 8),
                Text(
                  'الرصيد الإجمالي',
                  style: TextStyle(
                    color: AppColors.white.withOpacity(0.75),
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                // AI spark = the smart assistant is watching over this wallet.
                const Icon(Icons.auto_awesome,
                    color: AppColors.green, size: 16),
              ],
            ),
            const SizedBox(height: 8),
            // FittedBox: very large balances never overflow small phones.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                Helpers.money(balance, currency: currency),
                maxLines: 1,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: AppColors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: _Chip(
                    icon: Icons.arrow_downward_rounded,
                    label: 'الدخل',
                    value: income,
                    color: AppColors.green,
                    currency: currency,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Chip(
                    icon: Icons.arrow_upward_rounded,
                    label: 'المصروف',
                    value: expense,
                    color: const Color(0xFFFF6B6B),
                    currency: currency,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.currency,
  });

  final IconData icon;
  final String label;
  final double value;
  final Color color;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 14,
            backgroundColor: color.withOpacity(0.25),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.white.withOpacity(0.7),
                  ),
                ),
                Text(
                  Helpers.money(value, currency: currency),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
