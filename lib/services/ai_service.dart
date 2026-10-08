// ============================================================================
// AiService — the ONLY place that talks to the CodeCraft API.
//
// Endpoint : https://codecraftapi.com/v1/chat/completions
// Model    : claude-opus-5.5
// Auth     : Authorization: Bearer $CODECRAFT_API_KEY
//
// SECURITY (critical):
//   * The key is NEVER hardcoded and NEVER committed (.env is git-ignored).
//   * Read order:  runtime injection  ->  --dart-define  ->  secure storage.
//   * Recommended builds:
//       flutter run  --dart-define=CODECRAFT_API_KEY=cc_xxx
//       flutter build apk --release --dart-define-from-file=.env   (CI friendly)
//   * `--dart-define-from-file=.env` reads KEY=VALUE lines — so the same
//     .env file works for local dev and for the GitHub Action.
// ============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;


/// One message in a chat-completion request.
class AiChatTurn {
  const AiChatTurn({required this.role, required this.content});

  /// `system`, `user` or `assistant`.
  final String role;
  final String content;

  Map<String, String> toMap() => <String, String>{'role': role, 'content': content};
}

/// Structured transaction extracted by the AI from voice / text / receipts.
class AiParsedTransaction {
  const AiParsedTransaction({
    required this.type,
    required this.amount,
    required this.category,
    required this.date,
    required this.note,
  });

  final String type; // 'income' | 'expense'
  final double amount;
  final String category;
  final DateTime date;
  final String note;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'type': type,
        'amount': amount,
        'category': category,
        'date': date.toIso8601String(),
        'note': note,
      };
}

class AiService {
  AiService({http.Client? client, String? baseUrl, String? model, String? apiKey})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? _defaultBaseUrl,
        _model = model ?? _defaultModel {
    if (apiKey != null && apiKey.trim().isNotEmpty) {
      _injectedKey = apiKey.trim();
    }
  }

  static const String _defaultBaseUrl = 'https://codecraftapi.com/v1';
  static const String _defaultModel = 'claude-opus-5.5';
  static const String _keyEnvName = 'CODECRAFT_API_KEY';
  static const String _keySecureStore = 'codecraft_api_key';

  final http.Client _client;
  final String _baseUrl;
  String _model;

  String? _injectedKey;
  String? _overrideBaseUrl;
  String? _dotEnvKey;
  bool _dotEnvLoaded = false;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static final AiService instance = AiService();

  // ---------------------------------------------------------------------------
  // Configuration & key resolution
  // ---------------------------------------------------------------------------

  /// Inject a key at runtime (e.g. from Settings screen or a test).
  void configure({String? apiKey, String? baseUrl, String? model}) {
    if (apiKey != null) _injectedKey = apiKey.trim();
    if (baseUrl != null && baseUrl.trim().isNotEmpty) {
      _overrideBaseUrl = baseUrl.trim();
    }
    if (model != null && model.trim().isNotEmpty) _model = model.trim();
  }

  /// Resolves the API key: injection -> .env asset -> dart-define -> keystore.
  Future<String?> resolveApiKey() async {
    if (_injectedKey != null && _injectedKey!.isNotEmpty) return _injectedKey;
    await _loadDotEnvIfNeeded();
    if (_dotEnvKey != null && _dotEnvKey!.isNotEmpty) return _dotEnvKey;
    const String fromDefine = String.fromEnvironment(_keyEnvName);
    if (fromDefine.isNotEmpty) return fromDefine;
    try {
      return await _secureStorage.read(key: _keySecureStore);
    } catch (_) {
      return null;
    }
  }

  /// Parses a bundled `.env` asset (`KEY=VALUE` lines) — never committed.
  Future<void> _loadDotEnvIfNeeded() async {
    if (_dotEnvLoaded) return;
    _dotEnvLoaded = true;
    try {
      final String raw = await rootBundle.loadString('.env');
      for (final String line in LineSplitter.split(raw)) {
        final String trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final int eq = trimmed.indexOf('=');
        if (eq <= 0) continue;
        if (trimmed.substring(0, eq).trim() == _keyEnvName) {
          _dotEnvKey = trimmed.substring(eq + 1).trim();
          break;
        }
      }
    } catch (_) {
      // No bundled .env (expected in CI) — dart-define is used instead.
    }
  }

  /// True when a key exists — UI uses this to enable/disable AI features.
  Future<bool> hasApiKey() async {
    final String? k = await resolveApiKey();
    return k != null && k.isNotEmpty;
  }

  String get _effectiveBaseUrl => _overrideBaseUrl ?? _baseUrl;

  // ---------------------------------------------------------------------------
  // Core request layer
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _chatCompletion({
    required List<AiChatTurn> messages,
    double temperature = 0.2,
    int maxTokens = 1024,
  }) async {
    final String? apiKey = await resolveApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw const AiNotConfiguredException();
    }

    final Uri uri = Uri.parse('$_effectiveBaseUrl/chat/completions');
    final Map<String, String> headers = <String, String>{
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };
    final Map<String, dynamic> body = <String, dynamic>{
      'model': _model,
      'messages': messages.map((AiChatTurn m) => m.toMap()).toList(),
      'temperature': temperature,
      'max_tokens': maxTokens,
    };

    // One retry on transient failures (timeout / 5xx / rate limit).
    Object? lastError;
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final http.Response res = await _client
            .post(uri, headers: headers, body: jsonEncode(body))
            .timeout(const Duration(seconds: 45));

        if (res.statusCode == 200) {
          final Map<String, dynamic> data =
              jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
          return data;
        }
        if (res.statusCode >= 500 || res.statusCode == 429) {
          lastError = AiException(
              'CodeCraft API ${res.statusCode}: ${res.body}');
          await Future<void>.delayed(
              Duration(milliseconds: 700 * (attempt + 1)));
          continue;
        }
        throw AiException(
            'CodeCraft API ${res.statusCode}: ${res.body}');
      } on TimeoutException {
        lastError = const AiException('انتهت مهلة الاتصال بخدمة الذكاء الاصطناعي');
      } on AiException {
        rethrow;
      } catch (e) {
        lastError = const AiException('تعذر الاتصال بخدمة الذكاء الاصطناعي');
      }
    }
    throw lastError ?? const AiException('فشل طلب الذكاء الاصطناعي');
  }

  /// Returns the assistant's text reply for [messages].
  Future<String> completeText(
    List<AiChatTurn> messages, {
    double temperature = 0.6,
    int maxTokens = 1024,
  }) async {
    final Map<String, dynamic> data = await _chatCompletion(
      messages: messages,
      temperature: temperature,
      maxTokens: maxTokens,
    );
    final List<dynamic> choices =
        (data['choices'] as List<dynamic>? ?? <dynamic>[]);
    if (choices.isEmpty) throw const AiException('رد فارغ من النموذج');
    final Map<String, dynamic> message =
        (choices.first as Map<String, dynamic>)['message']
            as Map<String, dynamic>;
    return (message['content'] ?? '').toString().trim();
  }

  // ---------------------------------------------------------------------------
  // JSON extraction helper (models sometimes wrap JSON in ``` fences)
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _extractJson(String raw) =>
      extractJsonForTest(raw);

  /// Public (test-visible) JSON extractor: handles ``` fences and prose.
  @visibleForTesting
  static Map<String, dynamic> extractJsonForTest(String raw) {
    String text = raw.trim();
    final RegExp fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final RegExpMatch? m = fence.firstMatch(text);
    if (m != null) text = m.group(1)!.trim();
    final int start = text.indexOf('{');
    final int end = text.lastIndexOf('}');
    if (start >= 0 && end > start) {
      text = text.substring(start, end + 1);
    }
    final dynamic decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException('not a JSON object');
  }

  // ---------------------------------------------------------------------------
  // Feature 4 — Voice command parsing
  // صرفت 50 ريال مطعم -> {type: expense, amount: 50, category: food, ...}
  // ---------------------------------------------------------------------------

  Future<AiParsedTransaction?> parseVoiceCommand(String transcript) async {
    final String todayIso = DateTime.now().toIso8601String();
    final String prompt = '''
أنت مساعد محاسبي ذكي. استخرج بيانات المعاملة المالية من الجملة العربية (بأي لهجة).
أعد JSON فقط بهذا الشكل بدون أي كلام إضافي:
{"type":"expense","amount":0.0,"category":"food","date":"$todayIso","note":"وصف قصير"}
التصنيفات المسموحة: food, transport, bills, shopping, entertainment, health, education, salary, savings, other
قواعد:
- type = "expense" للصرف و "income" للدخل (اشتغل على كلمات مثل: صرفت/دفعت = expense، استلمت/وصلني/راتب = income).
- حوّل الأرقام العربية والهندية (٥٠ / ٥٠٠ ريال / جنيه) إلى رقم عادي.
- date = "$todayIso" إلا إذا ذُكر يوم صريح (أمس = الأمس بتاريخ أمس).
- لو المشتري ذكر تاريخ "الأسبوع اللي فات" استخدم آخر يوم فيه.
الجملة: "${transcript.trim()}"
JSON:''';

    final String reply = await completeText(
      <AiChatTurn>[AiChatTurn(role: 'user', content: prompt)],
      temperature: 0.0,
      maxTokens: 300,
    );
    try {
      return _parseTransactionJson(_extractJson(reply));
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Feature 5 — Auto-categorization for manual transactions
  // ---------------------------------------------------------------------------

  Future<String> categorizeTransaction({
    required String note,
    required double amount,
    required bool isIncome,
  }) async {
    final String prompt = '''
صنّف هذه المعاملة المالية المصرية/الخليجية إلى تصنيف واحد فقط.
التصنيفات المتاحة: food, transport, bills, shopping, entertainment, health, education, salary, savings, other
النوع: ${isIncome ? 'income' : 'expense'}
المبلغ: $amount
الوصف: "${note.trim()}"
أعد كلمة JSON فقط: {"category":"..."}''';

    final String reply = await completeText(
      <AiChatTurn>[AiChatTurn(role: 'user', content: prompt)],
      temperature: 0.0,
      maxTokens: 40,
    );
    try {
      final Map<String, dynamic> json = _extractJson(reply);
      final String cat = (json['category'] ?? '').toString().trim().toLowerCase();
      const List<String> allowed = <String>[
        'food', 'transport', 'bills', 'shopping', 'entertainment',
        'health', 'education', 'salary', 'savings', 'other',
      ];
      return allowed.contains(cat) ? cat : 'other';
    } catch (_) {
      return 'other';
    }
  }

  // ---------------------------------------------------------------------------
  // Feature 8 — OCR receipt text -> structured transaction
  // ---------------------------------------------------------------------------

  Future<AiParsedTransaction?> receiptToTransaction(String rawOcrText) async {
    final String todayIso = DateTime.now().toIso8601String();
    final String prompt = '''
هذا نص مستخرج بتقنية OCR من صورة فاتورة/إيصال. استخرج المعاملة الأساسية.
أعد JSON فقط:
{"type":"expense","amount":0.0,"category":"food","date":"$todayIso","note":"اسم المتجر أو وصف الفاتورة"}
التصنيفات: food, transport, bills, shopping, entertainment, health, education, salary, savings, other
- المبلغ = الإجمالي النهائي (المجموع / الإجمالي / TOTAL) وليس سعر صنف واحد.
- التاريخ من الفاتورة إن وُجد، وإلا "$todayIso".
نص الفاتورة:
"""
${rawOcrText.trim()}
"""
JSON:''';

    final String reply = await completeText(
      <AiChatTurn>[AiChatTurn(role: 'user', content: prompt)],
      temperature: 0.0,
      maxTokens: 300,
    );
    try {
      return _parseTransactionJson(_extractJson(reply));
    } catch (_) {
      return null;
    }
  }

  AiParsedTransaction _parseTransactionJson(Map<String, dynamic> json) {
    final double amount =
        (json['amount'] as num? ?? 0).toDouble().abs();
    final String type = (json['type'] ?? 'expense').toString();
    final DateTime date = DateTime.tryParse((json['date'] ?? '').toString()) ??
        DateTime.now();
    return AiParsedTransaction(
      type: type == 'income' ? 'income' : 'expense',
      amount: amount,
      category: (json['category'] ?? 'other').toString(),
      date: date,
      note: (json['note'] ?? '').toString(),
    );
  }

  // ---------------------------------------------------------------------------
  // Feature 6 — AI Chat Accountant (Egyptian persona + real user context)
  // ---------------------------------------------------------------------------

  static const String personaSystemPrompt =
      'You are a friendly Egyptian personal accountant, expert in saving money, '
      'answer in simple Arabic. Use Egyptian dialect warmth, keep answers short '
      'and practical, use bullet points, and give concrete numbers. Never invent '
      'data that is not in the provided context — if data is missing, say so.';

  /// Full chat reply with the user's real financial context injected.
  Future<String> chatWithAccountant({
    required String userMessage,
    required List<AiChatTurn> history,
    required String transactionsSummary,
  }) async {
    final List<AiChatTurn> messages = <AiChatTurn>[
      AiChatTurn(
        role: 'system',
        content: '$personaSystemPrompt\n\n'
            '=== بيانات المستخدم المالية الحالية ===\n'
            '$transactionsSummary\n'
            '=== نهاية البيانات ===',
      ),
      ...history,
      AiChatTurn(role: 'user', content: userMessage),
    ];
    return completeText(messages, temperature: 0.5, maxTokens: 900);
  }

  /// Builds a compact Arabic summary of the user's finances for the system
  /// prompt (current month + last 30 days by category).
  static String buildTransactionsSummary({
    required double monthIncome,
    required double monthExpense,
    required Map<String, double> expensesByCategory,
    required List<({String title, double amount})> topExpenses,
    String currency = 'ج.م',
  }) {
    final StringBuffer sb = StringBuffer();
    sb.writeln('دخل الشهر: ${monthIncome.toStringAsFixed(0)} $currency');
    sb.writeln('مصروف الشهر: ${monthExpense.toStringAsFixed(0)} $currency');
    sb.writeln(
        'الصافي: ${(monthIncome - monthExpense).toStringAsFixed(0)} $currency');
    if (expensesByCategory.isNotEmpty) {
      sb.writeln('المصروف حسب التصنيف:');
      final List<MapEntry<String, double>> sorted =
          expensesByCategory.entries.toList()
            ..sort((MapEntry<String, double> a, MapEntry<String, double> b) =>
                b.value.compareTo(a.value));
      for (final MapEntry<String, double> e in sorted) {
        sb.writeln('- ${e.key}: ${e.value.toStringAsFixed(0)} $currency');
      }
    }
    if (topExpenses.isNotEmpty) {
      sb.writeln('آخر عمليات صرف كبيرة:');
      for (final ({String title, double amount}) e in topExpenses.take(5)) {
        sb.writeln('- ${e.title}: ${e.amount.toStringAsFixed(0)} $currency');
      }
    }
    return sb.toString();
  }

  /// Free saving-tips generator (used by the dashboard tip card).
  Future<String> savingTip({
    required double monthIncome,
    required double monthExpense,
  }) async {
    final String reply = await completeText(
      <AiChatTurn>[
        const AiChatTurn(role: 'system', content: personaSystemPrompt),
        AiChatTurn(
          role: 'user',
          content: 'دخلي ${monthIncome.toStringAsFixed(0)} ومصروفي '
              '${monthExpense.toStringAsFixed(0)} هذا الشهر. '
              'أعطني نصيحة واحدة قصيرة جداً (سطرين بالطول) لأوفر فلوسي.',
        ),
      ],
      temperature: 0.8,
      maxTokens: 120,
    );
    return reply;
  }

  /// Closes the underlying HTTP client (used in tests).
  void dispose() => _client.close();
}

/// Thrown when no API key is configured — UI shows a friendly setup hint.
class AiNotConfiguredException implements Exception {
  const AiNotConfiguredException();
  @override
  String toString() =>
      'CODECRAFT_API_KEY is not configured (use --dart-define).';
}

/// Generic AI failure with an Arabic, user-facing message when possible.
class AiException implements Exception {
  const AiException(this.message);
  final String message;
  @override
  String toString() => message;
}
