// Paywall — PRO subscriptions (Monthly 15 SAR / Yearly 120 SAR) via
// Google Play Billing (in_app_purchase). Prices come from the store when
// available; the features grid explains the value. Purchases are granted
// through BillingService's purchase stream and persisted in Hive.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../providers/plan_provider.dart';
import '../../services/billing_service.dart';
import '../../utils/constants.dart';
import '../../widgets/custom_button.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  static const String routeName = '/paywall';

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  String _selected = IapIds.yearly; // yearly pre-selected (best value)
  bool _buying = false;
  bool _restoring = false;
  bool _storeReady = false;

  BillingService get _billing => ref.read(billingProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _billing.init();
      if (mounted) {
        setState(() => _storeReady = _billing.available && _billing.products.isNotEmpty);
      }
    });
  }

  Future<void> _buy() async {
    setState(() => _buying = true);
    final bool started = await _billing.purchase(_selected);
    if (!mounted) return;
    setState(() => _buying = false);
    if (!started) {
      Fluttertoast.showToast(
        msg: _storeReady
            ? 'تعذر بدء الدفع، حاول مرة أخرى'
            : 'خدمة الدفع غير متاحة (تحقق من حساب جوجل أو إعداد المنتجات في Play Console)',
        toastLength: Toast.LENGTH_LONG,
      );
      return;
    }
    // Purchase result arrives via BillingService stream -> Hive pro_until.
    // We optimistically refresh after a short grace period.
    await Future<void>.delayed(const Duration(seconds: 2));
    ref.read(isProProvider.notifier).set(BillingService.revalidatePro());
    if (!mounted) return;
    if (ref.read(isProProvider)) {
      Fluttertoast.showToast(msg: 'مبروك! أنت الآن مشترك PRO 🎉');
      Navigator.of(context).pop();
    }
  }

  Future<void> _restore() async {
    setState(() => _restoring = true);
    await _billing.restore();
    await Future<void>.delayed(const Duration(seconds: 2));
    ref.read(isProProvider.notifier).set(BillingService.revalidatePro());
    if (!mounted) return;
    setState(() => _restoring = false);
    Fluttertoast.showToast(
      msg: ref.read(isProProvider)
          ? 'تمت استعادة اشتراكك ✅'
          : 'لا يوجد اشتراك سابق للاستعادة',
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isPro = ref.watch(isProProvider);

    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: <Widget>[
          if (isPro)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('تم',
                  style: TextStyle(color: AppColors.green)),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: <Widget>[
            // ---- Hero ----
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFFF5A524).withOpacity(0.3),
                      blurRadius: 36,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    size: 64, color: Color(0xFFF5A524)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'المحاسب الذكي PRO',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'افتح كل قوة الذكاء الاصطناعي لإدارة فلوسك',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.white.withOpacity(0.75),
              ),
            ),
            const SizedBox(height: 24),

            // ---- Features ----
            _feature(Icons.mic_rounded, 'إدخال صوتي وتحليل فوري بلا حدود'),
            _feature(Icons.document_scanner_outlined, 'مسح الفواتير بالكاميرا (OCR)'),
            _feature(Icons.chat_rounded, 'محادثة غير محدودة مع المحاسب الآلي'),
            _feature(Icons.picture_as_pdf_rounded, 'تصدير تقارير PDF و Excel'),
            _feature(Icons.block_rounded, 'بدون إعلانات نهائياً'),
            _feature(Icons.sync_rounded, 'مزامنة سحابية كاملة عبر Firebase'),
            const SizedBox(height: 24),

            if (isPro) ...<Widget>[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                  border: Border.all(color: AppColors.green),
                ),
                child: const Text(
                  'أنت مشترك PRO بالفعل 🎉 شكراً لدعمك!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ] else ...<Widget>[
              // ---- Plans ----
              _PlanCard(
                title: 'شهري',
                price: _billing.priceOf(IapIds.monthly),
                note: 'إلغاء في أي وقت',
                selected: _selected == IapIds.monthly,
                onTap: () => setState(() => _selected = IapIds.monthly),
              ),
              const SizedBox(height: 12),
              _PlanCard(
                title: 'سنوي',
                price: _billing.priceOf(IapIds.yearly),
                note: 'وفّر ٣٣٪ — الأكثر شعبية 🔥',
                badge: 'الأفضل',
                selected: _selected == IapIds.yearly,
                onTap: () => setState(() => _selected = IapIds.yearly),
              ),
              const SizedBox(height: 20),
              CustomButton(
                label: _storeReady ? 'اشترك الآن' : 'الترقية إلى PRO',
                loading: _buying,
                icon: Icons.workspace_premium_rounded,
                onPressed: _buy,
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _restoring ? null : _restore,
                child: Text(
                  _restoring ? 'جاري الاستعادة...' : 'استعادة المشتريات',
                  style: TextStyle(
                    color: AppColors.white.withOpacity(0.7),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'الاشتراك يُجدد تلقائياً عبر Google Play ويمكن إلغاؤه في أي وقت '
              'من إعدادات حساب جوجل. الأسعار بالريال السعودي.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                color: AppColors.white.withOpacity(0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feature(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          const Icon(Icons.check_circle_rounded,
              color: AppColors.green, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: AppColors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.note,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String price;
  final String note;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.white.withOpacity(0.1)
              : AppColors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          border: Border.all(
            color: selected ? AppColors.green : AppColors.white.withOpacity(0.15),
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? AppColors.green : AppColors.textHint,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      if (badge != null) ...<Widget>[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(note,
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textHint)),
                ],
              ),
            ),
            Text(
              price,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                color: AppColors.green,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
