// Unit tests: AI service (CodeCraft API) parsing + helpers, no network.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_personal_accountant/models/transaction.dart';
import 'package:smart_personal_accountant/services/ai_service.dart';
import 'package:smart_personal_accountant/utils/helpers.dart';

void main() {
  group('AiService.extractJsonForTest', () {
    test('parses plain JSON', () {
      final Map<String, dynamic> out =
          AiService.extractJsonForTest('{"amount": 50}');
      expect(out['amount'], 50);
    });

    test('parses JSON inside markdown fences', () {
      final Map<String, dynamic> out = AiService.extractJsonForTest(
          'هذا هو:\n```json\n{"amount": 50.5, "type": "expense"}\n```');
      expect(out['amount'], 50.5);
      expect(out['type'], 'expense');
    });

    test('parses JSON surrounded by Arabic prose', () {
      final Map<String, dynamic> out = AiService.extractJsonForTest(
          'النتيجة: {"category":"food","amount":3} شكراً');
      expect(out['category'], 'food');
    });
  });

  group('AiService.parseVoiceCommand', () {
    test('sends the correct CodeCraft request and parses the reply', () async {
      late String capturedAuth;
      late Map<String, dynamic> capturedBody;

      final AiService ai = AiService(
        apiKey: 'test-key',
        client: MockClient((http.Request request) async {
          capturedAuth = request.headers['Authorization'] ?? '';
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'choices': <dynamic>[
                <String, dynamic>{
                  'message': <String, String>{
                    'content':
                        '{"type":"expense","amount":50,"category":"food",'
                            '"date":"2026-10-08T00:00:00.000","note":"مطعم"}'
                  }
                }
              ],
            }),
            200,
            headers: <String, String>{
              'content-type': 'application/json; charset=utf-8'
            },
          );
        }),
      );

      final AiParsedTransaction? result =
          await ai.parseVoiceCommand('صرفت ٥٠ ريال مطعم');

      expect(capturedAuth, 'Bearer test-key');
      expect(capturedBody['model'], 'claude-opus-5.5');
      expect(
        (capturedBody['messages'] as List<dynamic>).first['role'],
        'user',
      );
      expect(result, isNotNull);
      expect(result!.type, 'expense');
      expect(result.amount, 50);
      expect(result.category, 'food');
      expect(result.note, 'مطعم');
      ai.dispose();
    });

    test('falls back to the local parser on API error', () async {
      final AiService ai = AiService(
        apiKey: 'test-key',
        client: MockClient((http.Request request) async =>
            http.Response('{"error":"boom"}', 400)),
      );
      // Robustness contract: a dead API must never dead-end voice entry.
      final AiParsedTransaction? r = await ai.parseVoiceCommand('صرفت 50');
      expect(r, isNotNull);
      expect(r!.type, 'expense');
      expect(r.amount, 50);
      ai.dispose();
    });

    test('falls back to the local parser without a key', () async {
      final AiService ai = AiService(
        client: MockClient(
            (http.Request request) async => http.Response('{}', 200)),
      );
      final AiParsedTransaction? r = await ai.parseVoiceCommand('صرفت 50');
      expect(r, isNotNull);
      expect(r!.amount, 50);
      ai.dispose();
    });
  });

  group('LocalTransactionParser (offline fallback)', () {
    test('parses Egyptian expense phrase with Eastern digits', () {
      final AiParsedTransaction? r =
          LocalTransactionParser.parse('صرفت ٥٠ ريال مطعم');
      expect(r, isNotNull);
      expect(r!.type, 'expense');
      expect(r.amount, 50);
      expect(r.category, 'food');
    });

    test('parses income phrase', () {
      final AiParsedTransaction? r =
          LocalTransactionParser.parse('استلمت راتبي ٥٠٠٠ جنيه');
      expect(r, isNotNull);
      expect(r!.type, 'income');
      expect(r.amount, 5000);
      expect(r.category, 'salary');
    });

    test('parses decimal amounts and bills keyword', () {
      final AiParsedTransaction? r =
          LocalTransactionParser.parse('دفعت 125.5 فاتورة الكهربا');
      expect(r, isNotNull);
      expect(r!.type, 'expense');
      expect(r.amount, 125.5);
      expect(r.category, 'bills');
    });

    test('returns null when no amount present', () {
      expect(LocalTransactionParser.parse('مرحبا'), isNull);
    });

    test('parses transport phrase', () {
      final AiParsedTransaction? r =
          LocalTransactionParser.parse('صرفت ٣٠ جنيه اوبر');
      expect(r!.category, 'transport');
      expect(r.amount, 30);
    });
  });

  group('Helpers', () {
    test('sumBy aggregates by type', () {
      final List<Transaction> txs = <Transaction>[
        _tx(TxType.income, 100),
        _tx(TxType.expense, 30),
        _tx(TxType.expense, 20),
      ];
      expect(Helpers.sumBy(txs, TxType.income), 100);
      expect(Helpers.sumBy(txs, TxType.expense), 50);
    });

    test('expensesByCategory groups correctly', () {
      final List<Transaction> txs = <Transaction>[
        _tx(TxType.expense, 30, category: 'food'),
        _tx(TxType.expense, 10, category: 'food'),
        _tx(TxType.income, 500, category: 'salary'),
      ];
      final Map<String, double> out = Helpers.expensesByCategory(txs);
      expect(out['food'], 40);
      expect(out.containsKey('salary'), isFalse);
    });

    test('monthKey formats yyyy-MM', () {
      expect(Helpers.monthKey(DateTime(2026, 3, 8)), '2026-03');
      expect(
        Transaction(
          id: 'x',
          type: TxType.expense,
          category: 'food',
          amount: 5,
          date: DateTime(2026, 12, 31),
          createdAtMs: 0,
        ).monthKey(),
        '2026-12',
      );
    });
  });
}

Transaction _tx(TxType type, double amount, {String category = 'food'}) =>
    Transaction(
      id: 'id_${amount}_${type.name}',
      type: type,
      category: category,
      amount: amount,
      date: DateTime(2026, 10, 8),
      createdAtMs: 0,
    );
