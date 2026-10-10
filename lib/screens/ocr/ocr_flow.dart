// Shared OCR flow: PRO gate -> camera -> ML Kit scan -> AI parse -> confirm.
// Used by the dashboard quick action and the add-transaction sheet.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/plan_provider.dart';
import '../../services/ads_service.dart';
import '../../services/ai_service.dart';
import '../../services/ocr_service.dart';
import '../paywall/paywall_screen.dart';
import 'ocr_confirm_screen.dart';

abstract final class OcrFlow {
  /// Full receipt-scanning flow with the PRO gate built in.
  static Future<void> start(BuildContext context, WidgetRef ref) async {
    if (!ref.read(isProProvider)) {
      Fluttertoast.showToast(msg: 'مسح الفواتير ميزة PRO 👑');
      Navigator.of(context).pushNamed(PaywallScreen.routeName);
      return;
    }
    try {
      final XFile? photo = await ImagePicker()
          .pickImage(source: ImageSource.camera, imageQuality: 80);
      if (photo == null || !context.mounted) return;
      await AdsService.maybeShowInterstitial(every: 2);

      final OcrResult result = await OcrService.scanReceipt(
        photo.path,
        ai: AiService.instance,
      );
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => OcrConfirmScreen(result: result),
        ),
      );
    } catch (_) {
      Fluttertoast.showToast(msg: 'تعذر فتح الكاميرا');
    }
  }
}
