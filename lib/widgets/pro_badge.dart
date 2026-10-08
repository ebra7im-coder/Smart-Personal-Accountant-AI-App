// PRO badge + upsell banner used across screens.

import 'package:flutter/material.dart';

import '../utils/constants.dart';

class ProBadge extends StatelessWidget {
  const ProBadge({super.key, this.small = false});

  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 10,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFF5A524), Color(0xFFFFD166)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'PRO',
        style: TextStyle(
          fontSize: small ? 9 : 11,
          fontWeight: FontWeight.w800,
          color: AppColors.navy,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// Horizontal upsell card (shown to free users on dashboard & paywall link).
class ProUpsellBanner extends StatelessWidget {
  const ProUpsellBanner({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: <Color>[Color(0xFF123B75), AppColors.navy],
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          border: Border.all(color: const Color(0xFFF5A524), width: 1.2),
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5A524).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.workspace_premium_rounded,
                  color: Color(0xFFF5A524), size: 26),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'افتح كل مميزات PRO 👑',
                    style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'مسح الفواتير • تصدير • بدون إعلانات • AI بلا حدود',
                    style: TextStyle(
                      color: AppColors.textHint,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded,
                color: Color(0xFFF5A524), size: 26),
          ],
        ),
      ),
    );
  }
}
