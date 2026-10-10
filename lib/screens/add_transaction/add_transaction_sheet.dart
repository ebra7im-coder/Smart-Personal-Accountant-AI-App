// Add/Edit transaction sheet — the core "under 3 clicks" flow.
//
// Flow: FAB (mic) -> speak -> AI parses -> sheet pre-filled -> save. (3 taps)
//       + button -> type amount -> pick category chip -> save.        (3 taps)
// Features: voice input (speech_to_text + CodeCraft AI parse),
//           AI auto-categorization, OCR receipt scan (PRO),
//           offline Hive write, budget threshold re-check.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../models/transaction.dart';
import '../../providers/budget_provider.dart';
import '../../providers/plan_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/ai_service.dart';
import '../../services/hive_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../utils/validators.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/pro_badge.dart';
import '../ocr/ocr_flow.dart';
import '../paywall/paywall_screen.dart';

class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({
    super.key,
    this.existing,
    this.prefill,
    this.initialType,
  });

  /// When set, the sheet edits this transaction instead of creating one.
  final Transaction? existing;

  /// AI-prefilled values (voice / OCR / chat flow).
  final AiParsedTransaction? prefill;

  /// Pre-selected type for new transactions (dashboard quick actions).
  final TxType? initialType;

  /// Free-plan monthly quota gate. Returns false when blocked (paywall shown).
  static bool quotaBlocked(WidgetRef ref) {
    final bool isPro = ref.read(isProProvider);
    if (isPro) return false;
    final String mk = Helpers.monthKey(DateTime.now());
    final int used = HiveService.countTransactionsForMonth(mk);
    if (used >= PlanLimits.freeTransactionsPerMonth) {
      Fluttertoast.showToast(
        msg: 'وصلت الحد المجاني (٧٠ معاملة/شهر) — قم بالترقية للمتابعة',
        toastLength: Toast.LENGTH_LONG,
      );
      return true;
    }
    return false;
  }

  /// Entry point from HomeShell: free-plan quota is checked here.
  static Future<void> maybeShow(BuildContext context, WidgetRef ref) async {
    if (quotaBlocked(ref)) {
      if (context.mounted) {
        Navigator.of(context).pushNamed(PaywallScreen.routeName);
      }
      return;
    }
    if (context.mounted) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const AddTransactionSheet(),
      );
    }
  }

  /// Same as [maybeShow] but with a pre-selected income/expense toggle.
  static Future<void> maybeShowWithType(
    BuildContext context,
    WidgetRef ref,
    TxType type,
  ) async {
    if (quotaBlocked(ref)) {
      if (context.mounted) {
        Navigator.of(context).pushNamed(PaywallScreen.routeName);
      }
      return;
    }
    if (context.mounted) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => AddTransactionSheet(initialType: type),
      );
    }
  }

  static Future<void> showWithPrefill(
    BuildContext context,
    AiParsedTransaction? prefill, {
    Transaction? existing,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AddTransactionSheet(prefill: prefill, existing: existing),
    );
  }

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final SpeechToText _speech = SpeechToText();

  TxType _type = TxType.expense;
  String _category = 'food';
  DateTime _date = DateTime.now();
  bool _busy = false;

  /// True once the user manually picks a category — disables AI
  /// auto-categorization so we never override a deliberate choice.
  bool _categoryTouched = false;

  // Voice state
  bool _speechAvailable = false;
  bool _listening = false;
  bool _aiParsing = false;
  String _transcript = '';

  @override
  void initState() {
    super.initState();
    final Transaction? existing = widget.existing;
    final AiParsedTransaction? prefill = widget.prefill;
    if (existing != null) {
      _type = existing.type;
      _category = existing.category;
      _date = existing.date;
      _amountCtrl.text = existing.amount.toStringAsFixed(2);
      _noteCtrl.text = existing.note;
    } else if (prefill != null) {
      _type = prefill.type == 'income' ? TxType.income : TxType.expense;
      _category = prefill.category;
      _date = prefill.date;
      _amountCtrl.text =
          prefill.amount > 0 ? prefill.amount.toStringAsFixed(2) : '';
      _noteCtrl.text = prefill.note;
      _categoryTouched = prefill.amount > 0; // AI already chose a category
    } else if (widget.initialType != null) {
      _type = widget.initialType!;
    }
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (String status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _listening = false);
          }
        },
        onError: (dynamic _) {
          if (mounted) setState(() => _listening = false);
        },
      );
    } catch (_) {
      _speechAvailable = false;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    try {
      _speech.stop();
    } catch (_) {}
    super.dispose();
  }

  // ----------------------------- Voice -----------------------------

  Future<void> _toggleMic() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    if (!_speechAvailable) {
      Fluttertoast.showToast(msg: 'الميكروفون غير متاح على الجهاز');
      await _initSpeech();
      return;
    }
    setState(() {
      _listening = true;
      _transcript = '';
    });
    await _speech.listen(
      localeId: 'ar',
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
      onResult: (dynamic result) {
        if (!mounted) return;
        setState(() => _transcript = result.recognizedWords ?? '');
        if (result.finalResult == true && _transcript.trim().isNotEmpty) {
          _parseWithAi(_transcript);
        }
      },
    );
  }

  Future<void> _parseWithAi(String transcript) async {
    setState(() => _aiParsing = true);
    try {
      final AiParsedTransaction? parsed =
          await AiService.instance.parseVoiceCommand(transcript);
      if (!mounted) return;
      if (parsed == null || parsed.amount <= 0) {
        Fluttertoast.showToast(msg: 'معرفتش أفهم الجملة، جرّب تكتبها يدوياً');
        return;
      }
      setState(() {
        _type = parsed.type == 'income' ? TxType.income : TxType.expense;
        _category = parsed.category;
        _categoryTouched = true;
        _date = parsed.date;
        _amountCtrl.text = parsed.amount.toStringAsFixed(2);
        _noteCtrl.text = parsed.note;
      });
      Fluttertoast.showToast(msg: 'تم التحليل تلقائياً ✨');
    } catch (_) {
      Fluttertoast.showToast(msg: 'تعذر تحليل الجملة، اكتبها يدوياً');
    } finally {
      if (mounted) setState(() => _aiParsing = false);
    }
  }

  // ----------------------------- OCR -----------------------------

  Future<void> _openScanner() => OcrFlow.start(context, ref);

  // ----------------------------- Save -----------------------------

  Future<void> _autoCategorize() async {
    // AI auto-categorization when the user typed a note and did NOT pick a
    // category manually (bug fix: previously never ran because the default
    // category was 'food', not 'other').
    if (_categoryTouched || _noteCtrl.text.trim().isEmpty) return;
    try {
      final String cat = await AiService.instance.categorizeTransaction(
        note: _noteCtrl.text.trim(),
        amount: double.tryParse(_amountCtrl.text) ?? 0,
        isIncome: _type == TxType.income,
      );
      if (mounted && cat != 'other') setState(() => _category = cat);
    } catch (_) {/* keep manual category */}
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    await _autoCategorize();

    final double amount = double.tryParse(_amountCtrl.text) ?? 0;
    final Transaction tx = Transaction(
      id: widget.existing?.id ??
          'tx_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}',
      type: _type,
      category: _category,
      amount: amount,
      date: _date,
      note: _noteCtrl.text.trim(),
      createdAtMs:
          widget.existing?.createdAtMs ?? DateTime.now().millisecondsSinceEpoch,
      source: widget.existing?.source ??
          (_transcript.isNotEmpty ? 'voice' : 'manual'),
      synced: widget.existing?.synced ?? false,
    );

    bool ok = true;
    if (widget.existing != null) {
      await ref.read(transactionListProvider.notifier).update(tx);
    } else {
      ok = await ref.read(transactionListProvider.notifier).add(tx);
    }

    if (!mounted) return;
    if (!ok) {
      setState(() => _busy = false);
      Fluttertoast.showToast(
        msg: 'وصلت الحد المجاني (٧٠ معاملة/شهر) — قم بالترقية للمتابعة',
        toastLength: Toast.LENGTH_LONG,
      );
      Navigator.of(context).pushNamed(PaywallScreen.routeName);
      return;
    }

    // Budget threshold engine (80% / 100% local notifications).
    await ref.read(budgetActionsProvider).checkThresholds();

    if (!mounted) return;
    Fluttertoast.showToast(msg: 'تم الحفظ بنجاح ✅');
    Navigator.of(context).pop();
  }

  // ----------------------------- UI -----------------------------

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bool isEditing = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // ---- Header ----
              Row(
                children: <Widget>[
                  Text(
                    isEditing ? 'تعديل المعاملة' : 'إضافة معاملة',
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _openScanner,
                    tooltip: 'مسح فاتورة (PRO)',
                    icon: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.document_scanner_outlined,
                            size: 20, color: AppColors.navy),
                        SizedBox(width: 4),
                        ProBadge(small: true),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),

              // ---- Voice bar ----
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _listening ? AppColors.greenSoft : AppColors.bg,
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  border: Border.all(
                    color: _listening ? AppColors.green : AppColors.line,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    GestureDetector(
                      onTap: _toggleMic,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: _listening ? AppColors.green : AppColors.navy,
                          shape: BoxShape.circle,
                          boxShadow: _listening
                              ? <BoxShadow>[
                                  BoxShadow(
                                    color: AppColors.green.withOpacity(0.5),
                                    blurRadius: 14,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: _aiParsing
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : Icon(
                                _listening ? Icons.stop_rounded : Icons.mic,
                                color: AppColors.white,
                                size: 22,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _aiParsing
                            ? 'جاري التحليل بالذكاء الاصطناعي...'
                            : _transcript.isNotEmpty
                                ? _transcript
                                : _listening
                                    ? 'جاري الاستماع... قول مثلاً: صرفت ٥٠ ريال مطعم'
                                    : 'اضغط الميكروفون وقول: صرفت ٥٠ ريال مطعم',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: _transcript.isNotEmpty
                              ? AppColors.textDark
                              : AppColors.textGrey,
                          fontWeight:
                              _listening ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ---- Type toggle ----
              Row(
                children: <Widget>[
                  Expanded(
                    child: _TypeToggle(
                      label: 'مصروف',
                      icon: Icons.arrow_upward_rounded,
                      selected: _type == TxType.expense,
                      color: AppColors.danger,
                      onTap: () => setState(() => _type = TxType.expense),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TypeToggle(
                      label: 'دخل',
                      icon: Icons.arrow_downward_rounded,
                      selected: _type == TxType.income,
                      color: AppColors.green,
                      onTap: () => setState(() => _type = TxType.income),
                    ),
                  ),
                ],
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
                  fontFamily: 'Tajawal',
                ),
                validator: Validators.amount,
                decoration: InputDecoration(
                  hintText: '0',
                  suffixText: 'ج.م',
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusL),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ---- Categories ----
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'التصنيف ${_noteCtrl.text.isNotEmpty ? '(AI يرشح الأنسب تلقائياً)' : ''}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textGrey,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CategoryX.expenseKeys
                    .map((String key) => CategoryChip(
                          categoryKey: key,
                          selected: _category == key,
                          onTap: () => setState(() {
                            _category = key;
                            _categoryTouched = true;
                          }),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),

              // ---- Date + note ----
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                          locale: const Locale('ar'),
                        );
                        if (picked != null) {
                          setState(() => _date = picked);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.line),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.calendar_month_rounded, size: 18),
                      label: Text(
                        Helpers.smartDate(_date),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _noteCtrl,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _save(),
                      decoration: const InputDecoration(
                        hintText: 'ملاحظة (اختياري — الـ AI يصنف تلقائياً)',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ---- Save ----
              SizedBox(
                height: AppSizes.buttonH,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    disabledBackgroundColor: AppColors.green.withOpacity(0.5),
                  ),
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.white),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(isEditing ? 'تحديث' : 'حفظ المعاملة'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          border: Border.all(
            color: selected ? color : AppColors.line,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon,
                size: 18,
                color: selected ? AppColors.white : AppColors.textHint),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.white : AppColors.textGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
