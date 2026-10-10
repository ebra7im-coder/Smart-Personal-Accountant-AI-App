// Settings screen: account, security (biometric lock), sync, data export,
// currency, PRO management and about.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';
import '../../models/transaction.dart';
import '../../providers/plan_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/export_service.dart';
import '../../services/firebase_service.dart';
import '../../services/hive_service.dart';
import '../../services/security_service.dart';
import '../../services/sync_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/pro_badge.dart';
import '../paywall/paywall_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _syncing = false;
  String _version = '1.0.0';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool canBio = await SecurityService.canUseBiometrics();
    if (!mounted) return;
    setState(() {
      _biometricEnabled = prefs.getBool(PrefKeys.biometricEnabled) ?? false;
      _biometricAvailable = canBio;
    });
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = info.version);
    } catch (_) {}
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final bool ok = await SecurityService.authenticate('فعّل القفل بالبصمة');
      if (!ok) return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefKeys.biometricEnabled, value);
    setState(() => _biometricEnabled = value);
    Fluttertoast.showToast(
        msg: value ? 'تم تفعيل القفل بالبصمة 🔒' : 'تم إيقاف القفل');
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    final bool changed = await ref.read(syncServiceProvider).syncAll(
      onLocalReplaced: (List<Transaction> txs) {
        ref.read(transactionListProvider.notifier).replaceAll(txs);
      },
    );
    if (!mounted) return;
    setState(() => _syncing = false);
    Fluttertoast.showToast(
      msg: FirebaseAuthService.isSignedIn
          ? 'تمت المزامنة ☁️${changed ? ' (تم رفع بيانات معلقة)' : ''}'
          : 'سجل دخول أولاً لتمكين المزامنة السحابية',
    );
  }

  Future<void> _exportAll() async {
    if (!ref.read(isProProvider)) {
      Navigator.of(context).pushNamed(PaywallScreen.routeName);
      return;
    }
    try {
      final List<Transaction> txs = ref.read(transactionListProvider);
      if (txs.isEmpty) {
        Fluttertoast.showToast(msg: 'لا توجد معاملات للتصدير');
        return;
      }
      final double income = Helpers.sumBy(txs, TxType.income);
      final double expense = Helpers.sumBy(txs, TxType.expense);
      final Uint8List bytes = await ExportService.generatePdf(
        transactions: txs,
        title: 'تقرير شامل — كل المعاملات',
        totalIncome: income,
        totalExpense: expense,
      );
      await ExportService.shareFile(
        bytes,
        'all_transactions_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (_) {
      Fluttertoast.showToast(msg: 'تعذر التصدير');
    }
  }

  Future<void> _logout() async {
    final bool? sure = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هتقدر ترجع وتلاقي بياناتك محفوظة على الجهاز.'),
        actions: <TextButton>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child:
                const Text('خروج', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await FirebaseAuthService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isPro = ref.watch(isProProvider);
    final DateTime? proUntil = HiveService.proUntil();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('الإعدادات'),
        backgroundColor: AppColors.bg,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // ---- Account / plan ----
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: <Color>[AppColors.navy, Color(0xFF164080)],
              ),
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
            ),
            child: Row(
              children: <Widget>[
                const CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.green,
                  child: Icon(Icons.person_rounded,
                      color: AppColors.white, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              FirebaseAuthService.isSignedIn
                                  ? 'حسابي'
                                  : 'وضع محلي (بدون حساب)',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isPro) const ProBadge(small: true),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isPro && proUntil != null
                            ? 'اشتراك PRO حتى ${Helpers.dateShort(proUntil)}'
                            : 'الخطة المجانية — ٧٠ معاملة/شهر',
                        style: TextStyle(
                          color: AppColors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _Group(title: 'الاشتراك', children: <Widget>[
            _Tile(
              icon: Icons.workspace_premium_rounded,
              label: isPro ? 'إدارة اشتراك PRO' : 'الترقية إلى PRO',
              subtitle: 'مسح الفواتير، تصدير، بدون إعلانات، AI بلا حدود',
              onTap: () =>
                  Navigator.of(context).pushNamed(PaywallScreen.routeName),
              trailing: const Icon(Icons.chevron_left_rounded, size: 22),
            ),
          ]),

          _Group(title: 'الأمان', children: <Widget>[
            SwitchListTile(
              value: _biometricEnabled,
              onChanged: _biometricAvailable ? _toggleBiometric : null,
              secondary:
                  const Icon(Icons.fingerprint_rounded, color: AppColors.navy),
              title: const Text('قفل التطبيق بالبصمة',
                  style: TextStyle(fontSize: 14)),
              subtitle: Text(
                _biometricAvailable
                    ? 'سيُطلب التحقق عند فتح التطبيق'
                    : 'غير متاح على هذا الجهاز',
                style: const TextStyle(fontSize: 11.5),
              ),
            ),
          ]),

          _Group(title: 'البيانات', children: <Widget>[
            _Tile(
              icon: Icons.sync_rounded,
              label: 'مزامنة الآن',
              subtitle: 'رفع/تنزيل بياناتك من Firebase',
              onTap: _syncing ? null : _syncNow,
              trailing: _syncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_left_rounded, size: 22),
            ),
            _Tile(
              icon: Icons.picture_as_pdf_rounded,
              label: 'تصدير كل المعاملات PDF',
              subtitle: 'ملف PDF عربي جاهز للمشاركة',
              onTap: _exportAll,
              trailing: const Icon(Icons.chevron_left_rounded, size: 22),
            ),
            _Tile(
              icon: Icons.delete_sweep_rounded,
              label: 'تفريغ سجل المحادثة',
              subtitle: 'حذف رسائل المحاسب الآلي من الجهاز',
              onTap: () async {
                await HiveService.clearChat();
                Fluttertoast.showToast(msg: 'تم التفريغ');
              },
              trailing: const Icon(Icons.chevron_left_rounded, size: 22),
            ),
          ]),

          _Group(title: 'عن التطبيق', children: <Widget>[
            const _Tile(
              icon: Icons.info_outline_rounded,
              label: 'المحاسب الذكي',
              subtitle: 'الإصدار 1.0.0 • مبني بـ Flutter + CodeCraft AI',
              showArrow: false,
            ),
            _Tile(
              icon: Icons.logout_rounded,
              label: 'تسجيل الخروج',
              subtitle: 'بياناتك تبقى محفوظة على الجهاز',
              onTap: _logout,
              trailing: const Icon(Icons.chevron_left_rounded, size: 22),
            ),
          ]),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'صُنع بـ 💚 — المحاسب الذكي v$_version',
              style: const TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 4, bottom: 8),
            child: Text(title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHint,
                )),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.onTap,
    this.trailing,
    this.showArrow = true,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.navy, size: 22),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
      trailing: showArrow
          ? (trailing ?? const Icon(Icons.chevron_left_rounded, size: 22))
          : trailing,
    );
  }
}
