// OCR confirm screen (PRO): shows scanned receipt text + AI-parsed fields.
// The user can fix anything before saving. Saves offline-first via the
// transaction provider, exactly like a manual transaction.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../models/transaction.dart';
import '../../providers/transaction_provider.dart';
import '../../services/ai_service.dart';
import '../../services/ocr_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/empty_state.dart';

class OcrConfirmScreen extends ConsumerStatefulWidget {
  const OcrConfirmScreen({super.key, required this.result});

  final OcrResult result;

  @override
  ConsumerState<OcrConfirmScreen> createState() => _OcrConfirmScreenState();
}

class _OcrConfirmScreenState extends ConsumerState<OcrConfirmScreen> {
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  String _category = 'other';
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final AiParsedTransaction? parsed = widget.result.parsed;
    if (parsed != null) {
      _category = parsed.category;
      _date = parsed.date;
      _amountCtrl.text =
          parsed.amount > 0 ? parsed.amount.toStringAsFixed(2) : '';
      _noteCtrl.text = parsed.note;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (widget.result.isEmpty) return;
    final double? amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      Fluttertoast.showToast(msg: 'من فضلك أدخل المبلغ');
      return;
    }
    setState(() => _saving = true);

    final Transaction tx = Transaction(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}',
      type: TxType.expense,
      category: _category,
      amount: amount,
      date: _date,
      note: _noteCtrl.text.trim(),
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      source: 'ocr',
    );

    final bool ok = await ref.read(transactionListProvider.notifier).add(tx);
    if (!mounted) return;
    if (!ok) {
      Fluttertoast.showToast(
          msg: 'وصلت الحد المجاني — قم بالترقية إلى PRO للمتابعة');
      return;
    }
    Fluttertoast.showToast(msg: 'تم تحليل الفاتورة وتسجيلها ✅');
    Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    // Empty scan (blurry photo / no text found).
    if (widget.result.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(title: const Text('مسح فاتورة')),
        body: EmptyState(
          icon: Icons.document_scanner_outlined,
          title: 'ما قدرناش نقرأ الفاتورة',
          subtitle: 'جرّب تصوير الفاتورة في إضاءة كويسة ومن مسافة قريبة',
          actionLabel: 'إعادة المحاولة',
          onAction: () => Navigator.of(context).pop(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('مراجعة الفاتورة')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            // ---- AI parsed summary ----
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.greenSoft,
                borderRadius: BorderRadius.circular(AppSizes.radiusL),
                border: Border.all(color: AppColors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.auto_awesome,
                      color: AppColors.green, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.result.parsed != null
                          ? 'الذكاء الاصطناعي حلل الفاتورة — راجع البيانات واحفظ'
                          : 'تم استخراج نص الفاتورة — أكمل البيانات يدوياً',
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ---- Amount ----
            TextFormField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Tajawal'),
              decoration: InputDecoration(
                hintText: '0',
                suffixText: 'ج.م',
                filled: true,
                fillColor: AppColors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ---- Category ----
            const Text('التصنيف',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textGrey)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CategoryX.expenseKeys
                  .map((String key) => CategoryChip(
                        categoryKey: key,
                        selected: _category == key,
                        onTap: () => setState(() => _category = key),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),

            // ---- Date ----
            OutlinedButton.icon(
              onPressed: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                  locale: const Locale('ar'),
                );
                if (picked != null) setState(() => _date = picked);
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.line),
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppColors.white,
              ),
              icon: const Icon(Icons.calendar_month_rounded, size: 18),
              label: Text(Helpers.smartDate(_date)),
            ),
            const SizedBox(height: 16),

            // ---- Note ----
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(hintText: 'ملاحظة'),
            ),
            const SizedBox(height: 16),

            // ---- Raw OCR text (collapsible) ----
            Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text(
                  'النص المستخرج من الفاتورة',
                  style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                ),
                children: <Widget>[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Text(
                      widget.result.rawText,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textGrey),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ---- Save ----
            SizedBox(
              height: AppSizes.buttonH,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.white),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('حفظ الفاتورة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
