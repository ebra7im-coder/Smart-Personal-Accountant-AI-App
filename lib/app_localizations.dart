// Localization setup: one Arabic .arb file (the app is 100% Arabic by design).
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Delegate providing the Arabic `AppLocalizations`.
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true; // Arabic-only app

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(const AppLocalizations());

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}

class AppLocalizations {
  const AppLocalizations();

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ];

  static const List<Locale> supportedLocales = <Locale>[Locale('ar')];

  // ---- App strings (Arabic) ----
  String get appName => 'المحاسب الذكي';
  String get login => 'تسجيل الدخول';
  String get register => 'إنشاء حساب';
  String get email => 'البريد الإلكتروني';
  String get password => 'كلمة المرور';
  String get fullName => 'الاسم الكامل';
  String get phone => 'رقم الهاتف';
  String get continueAsGuest => 'المتابعة كزائر';
  String get forgotPassword => 'نسيت كلمة المرور؟';
  String get dashboard => 'الرئيسية';
  String get transactions => 'المعاملات';
  String get chat => 'المحاسب الآلي';
  String get reports => 'التقارير';
  String get settings => 'الإعدادات';
  String get totalBalance => 'الرصيد الإجمالي';
  String get income => 'الدخل';
  String get expense => 'المصروف';
  String get recentTransactions => 'أحدث المعاملات';
  String get monthlyOverview => 'نظرة شهرية';
  String get noTransactions => 'لا توجد معاملات بعد';
  String get noTransactionsHint => 'اضغط زر + لإضافة أول معاملة';
  String get addTransaction => 'إضافة معاملة';
  String get editTransaction => 'تعديل المعاملة';
  String get amount => 'المبلغ';
  String get category => 'التصنيف';
  String get date => 'التاريخ';
  String get note => 'ملاحظة';
  String get save => 'حفظ';
  String get delete => 'حذف';
  String get update => 'تحديث';
  String get voiceInput => 'إدخال صوتي';
  String get voiceHint => 'قول مثلاً: صرفت ٥٠ ريال مطعم';
  String get listening => 'جاري الاستماع...';
  String get chatHint => 'اسأل محاسبك الآلي...';
  String get send => 'إرسال';
  String get budgets => 'الميزانيات';
  String get monthlyBudget => 'الميزانية الشهرية';
  String get budgetFor => 'ميزانية';
  String get ocrScan => 'مسح فاتورة';
  String get scanReceipt => 'امسح الفاتورة بالكاميرا';
  String get proFeature => 'ميزة PRO';
  String get upgradeToPro => 'الترقية إلى PRO';
  String get monthlyPlan => 'شهري';
  String get yearlyPlan => 'سنوي';
  String get subscribe => 'اشترك';
  String get restore => 'استعادة المشتريات';
  String get biometricLock => 'قفل بالبصمة';
  String get exportPdf => 'تصدير PDF';
  String get exportExcel => 'تصدير Excel';
  String get daily => 'يومي';
  String get weekly => 'أسبوعي';
  String get monthly => 'شهري';
  String get yearly => 'سنوي';
  String get logout => 'تسجيل الخروج';
  String get deleteAccount => 'حذف الحساب';
  String get errorGeneric => 'حدث خطأ، حاول مرة أخرى';
  String get successSaved => 'تم الحفظ بنجاح';
  String get amountRequired => 'من فضلك أدخل المبلغ';
  String get offlineMode => 'أنت بدون اتصال — سيتم المزامنة لاحقاً';
  String get pendingSync => 'في انتظار المزامنة';
  String get synced => 'تمت المزامنة';
  String get freePlanLimit =>
      'وصلت الحد المجاني (٧٠ معاملة/شهر). قم بالترقية إلى PRO للمتابعة!';
}
