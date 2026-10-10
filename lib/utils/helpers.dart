// Formatting & math helpers (Arabic-first, offline-safe).

import 'package:flutter/material.dart'
    show Color, IconData, Icons, DateTimeRange;
import 'package:intl/intl.dart';

import '../models/transaction.dart';

abstract final class Helpers {
  // ---------- Numbers & currency ----------

  static final NumberFormat _money = NumberFormat.decimalPattern('ar');
  static final NumberFormat _compact = NumberFormat.compact(locale: 'ar');

  /// `١٬٢٥٠ ج.م` style amount with the app currency.
  static String money(num amount, {String currency = 'ج.م'}) =>
      '${_money.format(amount)} $currency';

  static String compact(num amount) =>
      amount.abs() >= 100000 ? _compact.format(amount) : _money.format(amount);

  static String signed(TxType type, num amount) =>
      type == TxType.income ? '+${compact(amount)}' : '-${compact(amount)}';

  // ---------- Dates (Arabic Gregorian) ----------

  static String date(DateTime d) => DateFormat('d MMMM yyyy', 'ar').format(d);
  static String dateShort(DateTime d) => DateFormat('d/M/yyyy').format(d);
  static String time(DateTime d) =>
      DateFormat('hh:mm a', 'ar').format(d); // ص/م

  /// "اليوم"، "أمس"، وإلا التاريخ القصير.
  static String smartDate(DateTime d) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime target = DateTime(d.year, d.month, d.day);
    final int diff = today.difference(target).inDays;
    if (diff == 0) return 'اليوم';
    if (diff == 1) return 'أمس';
    if (diff == -1) return 'غداً';
    return dateShort(d);
  }

  /// `yyyy-MM` month key.
  static String monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  /// `yyyy-MM-dd` day key.
  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime monthKeyStart(String key) {
    final List<String> parts = key.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  static String monthName(DateTime d) =>
      DateFormat('MMMM yyyy', 'ar').format(d);

  /// Arabic weekday short name (السبت..الجمعة).
  static String weekdayName(DateTime d) => DateFormat('EEEE', 'ar').format(d);

  // ---------- Period ranges for reports ----------

  static DateTimeRange rangeFor(ReportPeriod period) {
    final DateTime now = DateTime.now();
    switch (period) {
      case ReportPeriod.daily:
        final DateTime start = DateTime(now.year, now.month, now.day);
        return DateTimeRange(start: start, end: now);
      case ReportPeriod.weekly:
        // Arabic week starts Saturday.
        final int daysFromSaturday = (now.weekday + 1) % 7;
        final DateTime start = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: daysFromSaturday));
        return DateTimeRange(start: start, end: now);
      case ReportPeriod.monthly:
        final DateTime start = DateTime(now.year, now.month);
        return DateTimeRange(start: start, end: now);
      case ReportPeriod.yearly:
        final DateTime start = DateTime(now.year);
        return DateTimeRange(start: start, end: now);
    }
  }

  static List<DateTime> monthRange(String monthKey) {
    final DateTime start = monthKeyStart(monthKey);
    final DateTime end =
        DateTime(start.year, start.month + 1).subtract(const Duration(days: 1));
    return <DateTime>[start, end];
  }

  // ---------- Aggregations ----------

  static double sumBy(Iterable<Transaction> txs, TxType type) => txs
      .where((Transaction t) => t.type == type)
      .fold(0.0, (double s, Transaction t) => s + t.amount);

  /// Expense totals grouped by category key.
  static Map<String, double> expensesByCategory(Iterable<Transaction> txs) {
    final Map<String, double> out = <String, double>{};
    for (final Transaction t
        in txs.where((Transaction t) => t.type == TxType.expense)) {
      out[t.category] = (out[t.category] ?? 0) + t.amount;
    }
    return out;
  }

  /// Daily net expense totals for charts.
  static Map<DateTime, double> dailyExpenses(Iterable<Transaction> txs) {
    final Map<DateTime, double> out = <DateTime, double>{};
    for (final Transaction t
        in txs.where((Transaction t) => t.type == TxType.expense)) {
      final DateTime day = DateTime(t.date.year, t.date.month, t.date.day);
      out[day] = (out[day] ?? 0) + t.amount;
    }
    return out;
  }
}

/// Report periods used by the Reports screen & exporters.
enum ReportPeriod { daily, weekly, monthly, yearly }

extension ReportPeriodX on ReportPeriod {
  String get arLabel => switch (this) {
        ReportPeriod.daily => 'يومي',
        ReportPeriod.weekly => 'أسبوعي',
        ReportPeriod.monthly => 'شهري',
        ReportPeriod.yearly => 'سنوي',
      };
}

/// UI-friendly icon + localized label + Arabic keywords per category.
/// `keywordsAr` also feeds the AI auto-categorization prompt.
extension CategoryX on String {
  static const Map<String, (IconData, String, List<String>)> _catalog =
      <String, (IconData, String, List<String>)>{
    'food': (
      Icons.restaurant_rounded,
      'مطاعم وطعام',
      <String>[
        'مطعم',
        'اكل',
        'أكل',
        'فطار',
        'غدا',
        'عشا',
        'كافيه',
        'قهوة',
        'بيتزا',
        'برجر',
        'شاورما',
        'حلويات',
        'سوبر ماركت',
        'بقالة',
        'طلب',
        'دليفري'
      ]
    ),
    'transport': (
      Icons.directions_car_rounded,
      'مواصلات',
      <String>[
        'مواصلات',
        'اوبير',
        'اوبر',
        'كاريم',
        'أوبر',
        'كريم',
        'تاكسي',
        'بنزين',
        'وقود',
        'مترو',
        'باص',
        'أتوبيس',
        'قطار',
        'موقف',
        'صيانة عربية',
        'كورة'
      ]
    ),
    'bills': (
      Icons.receipt_long_rounded,
      'فواتير',
      <String>[
        'فاتورة',
        'فواتير',
        'كهربا',
        'مياه',
        'غاز',
        'نت',
        'انترنت',
        'تليفون',
        'محصول',
        'ايجار',
        'إيجار',
        'قسط',
        'تأمين'
      ]
    ),
    'shopping': (
      Icons.shopping_bag_rounded,
      'تسوق',
      <String>[
        'ملابس',
        'تسوق',
        'الحتياجات',
        'كتشوة',
        'نظارة',
        'حذاء',
        'شنطة',
        'عطر',
        'موبايل',
        'اكسسوارات'
      ]
    ),
    'entertainment': (
      Icons.sports_esports_rounded,
      'ترفيه',
      <String>[
        'سينما',
        'فلوجات',
        'لعبة',
        'العاب',
        'ألعاب',
        'خروجة',
        'سفر',
        'نزهة',
        'اشتراك',
        'نتفلكس',
        'يوتيوب',
        'شاشة'
      ]
    ),
    'health': (
      Icons.medical_services_rounded,
      'صحة',
      <String>[
        'دكتور',
        'دوا',
        'صيدلية',
        'علاج',
        'تحليل',
        'اشعة',
        'مستشفى',
        'اسنان',
        'عيادة',
        'جيم',
        'نادي'
      ]
    ),
    'education': (
      Icons.school_rounded,
      'تعليم',
      <String>['مدرسة', 'جامعة', 'كورس', 'دورة', 'كتب', 'دراسة', 'رسوم', 'درس']
    ),
    'salary': (
      Icons.work_rounded,
      'راتب',
      <String>['راتب', 'مرتب', 'شغل', 'معاش', 'مكافأة', 'بونص', 'عمولة']
    ),
    'savings': (
      Icons.savings_rounded,
      'ادخار',
      <String>['ادخار', 'توفير', 'حصالة', 'وديعة', 'استثمار', 'ذهب']
    ),
    'other': (Icons.category_rounded, 'أخرى', <String>[]),
  };

  static const Map<String, String> _incomeFallback = <String, String>{
    'salary': 'راتب',
    'savings': 'ادخار',
    'other': 'أخرى',
  };

  /// Localized Arabic label.
  String get arLabel => _catalog[this]?.$2 ?? 'أخرى';

  /// Material icon.
  IconData get icon => _catalog[this]?.$1 ?? Icons.category_rounded;

  /// Brand color (green for savings/salary-ish, else navy tints).
  Color get color {
    switch (this) {
      case 'food':
        return const Color(0xFFFF7043);
      case 'transport':
        return const Color(0xFF42A5F5);
      case 'bills':
        return const Color(0xFFAB47BC);
      case 'shopping':
        return const Color(0xFFFFA726);
      case 'entertainment':
        return const Color(0xFFEC407A);
      case 'health':
        return const Color(0xFF26C6DA);
      case 'education':
        return const Color(0xFF7E57C2);
      case 'salary':
      case 'savings':
        return const Color(0xFF00C896);
      default:
        return const Color(0xFF78909C);
    }
  }

  /// All expense-category keys (used by budgets & AI prompt).
  static List<String> get expenseKeys => _catalog.keys.toList();

  /// Arabic keyword list for this category.
  List<String> get keywords => _catalog[this]?.$3 ?? const <String>[];

  /// Income fallback label (salary/savings/other).
  String get incomeLabel => _incomeFallback[this] ?? arLabel;
}
