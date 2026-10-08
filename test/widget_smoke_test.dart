// Widget smoke tests: core widgets render without crashing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_personal_accountant/models/transaction.dart';
import 'package:smart_personal_accountant/utils/constants.dart';
import 'package:smart_personal_accountant/widgets/transaction_card.dart';

void main() {
  testWidgets('TransactionCard renders expense row', (WidgetTester tester) async {
    final Transaction tx = Transaction(
      id: 't1',
      type: TxType.expense,
      category: 'food',
      amount: 50,
      date: DateTime.now(),
      note: 'شاورما',
      createdAtMs: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: TransactionCard(transaction: tx)),
        ),
      ),
    );

    expect(find.text('شاورما'), findsOneWidget);
    expect(find.text('مطاعم وطعام'), findsOneWidget);
    expect(find.text('-50'), findsOneWidget);
  });

  testWidgets('Brand colors match the design system',
      (WidgetTester tester) async {
    expect(AppColors.navy, const Color(0xFF0F2A54));
    expect(AppColors.green, const Color(0xFF00C896));
    expect(AppColors.white, Colors.white);
    expect(AppColors.bg, const Color(0xFFF5F7FB));
  });
}
