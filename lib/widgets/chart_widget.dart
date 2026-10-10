// fl_chart based widgets: monthly bar chart + category donut.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../utils/constants.dart';
import '../utils/helpers.dart';

/// Daily-expense bar chart for the current month (dashboard).
class MonthlyBarChart extends StatelessWidget {
  const MonthlyBarChart({
    super.key,
    required this.dailyExpenses,
    required this.daysInMonth,
  });

  final Map<int, double> dailyExpenses;
  final int daysInMonth;

  @override
  Widget build(BuildContext context) {
    final List<int> days = List<int>.generate(daysInMonth, (int i) => i + 1);
    final double maxVal =
        dailyExpenses.values.fold(10.0, (double m, double v) => v > m ? v : m);

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          maxY: maxVal * 1.2,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: (daysInMonth / 6).ceilToDouble(),
                getTitlesWidget: (double value, TitleMeta meta) {
                  final int day = value.toInt();
                  if (day < 1 || day > daysInMonth) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '$day',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textHint,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (BarChartGroupData _) => AppColors.navy,
              getTooltipItem: (BarChartGroupData group, int groupIndex,
                  BarChartRodData rod, int rodIndex) {
                final double v = rod.toY;
                return BarTooltipItem(
                  Helpers.compact(v),
                  const TextStyle(
                      color: AppColors.white, fontWeight: FontWeight.w700),
                );
              },
            ),
          ),
          barGroups: days.map((int day) {
            final double v = dailyExpenses[day] ?? 0;
            return BarChartGroupData(
              x: day,
              barRods: <BarChartRodData>[
                BarChartRodData(
                  toY: v,
                  width: 6,
                  borderRadius: BorderRadius.circular(3),
                  color: v > 0 ? AppColors.green : AppColors.line,
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Donut chart of expenses grouped by category (reports & dashboard).
class CategoryDonutChart extends StatelessWidget {
  const CategoryDonutChart({super.key, required this.expensesByCategory});

  final Map<String, double> expensesByCategory;

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<String, double>> entries = expensesByCategory.entries
        .toList()
      ..sort((MapEntry<String, double> a, MapEntry<String, double> b) =>
          b.value.compareTo(a.value));
    final double total = entries.fold(
        0.0, (double s, MapEntry<String, double> e) => s + e.value);

    if (entries.isEmpty || total == 0) {
      return const SizedBox(
        height: 160,
        child: Center(
          child: Text('لا توجد مصروفات لعرضها',
              style: TextStyle(color: AppColors.textHint)),
        ),
      );
    }

    return Column(
      children: <Widget>[
        SizedBox(
          height: 170,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 44,
              centerSpaceColor: AppColors.bg,
              sections: entries.take(8).map((MapEntry<String, double> e) {
                final double pct = e.value / total * 100;
                return PieChartSectionData(
                  value: e.value,
                  radius: 30,
                  color: e.key.color,
                  showTitle: pct >= 8,
                  title: '${pct.toStringAsFixed(0)}٪',
                  titleStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: entries.take(8).map((MapEntry<String, double> e) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: e.key.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${e.key.arLabel} ${Helpers.compact(e.value)}',
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.textGrey),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}
