// HiveService — the offline-first local database layer.
//
// Boxes:
//   settings     (plaintext)  : flags, prefs, cached user, PRO cache.
//   data         (AES-256)    : budgets, chat history, pro expiry.
//   transactions (AES-256)    : every transaction keyed by its id.
//
// The AES key is generated once, stored in flutter_secure_storage
// (Android Keystore / iOS Keychain) and reused forever.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

import '../models/budget.dart';
import '../models/chat_message.dart';
import '../models/transaction.dart';

abstract final class HiveService {
  static const String settingsBox = 'settings';
  static const String dataBox = 'data';
  static const String transactionsBox = 'transactions';

  static const String _keyName = 'hive_encryption_key_v1';
  static const int _chatHistoryCap = 300;

  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static bool _keyWasGeneratedThisRun = false;

  /// Opens [name] with AES-256 encryption; the key lives in secure storage.
  static Future<void> openEncryptedBox<T>(String name) async {
    List<int> key = await _loadOrCreateKey();
    try {
      await Hive.openBox<T>(name, encryptionCipher: HiveAesCipher(key));
    } on HiveError {
      // A previously corrupted key/box: rotate the key once and retry.
      if (!_keyWasGeneratedThisRun) {
        key = await _regenerateKey();
        await Hive.openBox<T>(name, encryptionCipher: HiveAesCipher(key));
      } else {
        rethrow;
      }
    } catch (e) {
      // Corrupted box file (rare): wipe just this box and continue fresh.
      await Hive.deleteBoxFromDisk(name);
      await Hive.openBox<T>(name, encryptionCipher: HiveAesCipher(key));
    }
  }

  static Future<List<int>> _loadOrCreateKey() async {
    final String? stored = await _secure.read(key: _keyName);
    if (stored != null && stored.isNotEmpty) {
      return stored.codeUnits;
    }
    final List<int> key = Hive.generateSecureKey();
    await _secure.write(key: _keyName, value: String.fromCharCodes(key));
    _keyWasGeneratedThisRun = true;
    return key;
  }

  static Future<List<int>> _regenerateKey() async {
    final List<int> key = Hive.generateSecureKey();
    await _secure.write(key: _keyName, value: String.fromCharCodes(key));
    _keyWasGeneratedThisRun = true;
    return key;
  }

  // ----------------------- generic accessors -----------------------

  static Box<dynamic> get _settings => Hive.box<dynamic>(settingsBox);
  static Box<dynamic> get _data => Hive.box<dynamic>(dataBox);
  static Box<Transaction> get _txs => Hive.box<Transaction>(transactionsBox);

  static T? get<T>(String boxName, String key) {
    try {
      final dynamic v = boxName == settingsBox
          ? _settings.get(key)
          : _data.get(key);
      return v is T ? v as T? : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> put(String boxName, String key, Object value) async {
    if (boxName == settingsBox) {
      await _settings.put(key, value);
    } else {
      await _data.put(key, value);
    }
  }

  static Future<void> delete(String boxName, String key) async {
    if (boxName == settingsBox) {
      await _settings.delete(key);
    } else {
      await _data.delete(key);
    }
  }

  // ----------------------- transactions -----------------------

  static Future<void> saveTransaction(Transaction tx) =>
      _txs.put(tx.id, tx);

  static List<Transaction> loadAllTransactions() => _txs.values.toList();

  static Transaction? getTransaction(String id) {
    try {
      return _txs.get(id);
    } catch (_) {
      return null;
    }
  }

  static Future<void> deleteTransaction(String id) => _txs.delete(id);

  static List<String> unsyncedIds() => _txs.values
      .where((Transaction t) => !t.synced)
      .map((Transaction t) => t.id)
      .toList();

  static Future<void> markSynced(String id) async {
    final Transaction? tx = getTransaction(id);
    if (tx != null) {
      final Transaction synced = Transaction(
        id: tx.id,
        type: tx.type,
        category: tx.category,
        amount: tx.amount,
        date: tx.date,
        note: tx.note,
        createdAtMs: tx.createdAtMs,
        source: tx.source,
        synced: true,
      );
      await _txs.put(id, synced);
    }
  }

  static int countTransactionsForMonth(String monthKey) => _txs.values
      .where((Transaction t) => t.monthKey() == monthKey)
      .length;

  // ----------------------- budgets -----------------------

  static Future<void> saveBudget(Budget b) =>
      _data.put('budget_${b.key}', b);

  static List<Budget> loadBudgets(String monthKey) {
    try {
      return _data.values
          .whereType<Budget>()
          .where((Budget b) => b.monthKey == monthKey)
          .toList();
    } catch (_) {
      return <Budget>[];
    }
  }

  static Future<void> deleteBudget(String key) =>
      _data.delete('budget_$key');

  // ----------------------- AI chat history -----------------------

  static List<ChatMessage> loadChat() {
    try {
      final dynamic raw = _data.get('chat_history');
      if (raw is List) {
        return raw.whereType<ChatMessage>().toList();
      }
    } catch (_) {}
    return <ChatMessage>[];
  }

  static Future<void> saveChat(List<ChatMessage> messages) {
    final List<ChatMessage> capped = messages.length > _chatHistoryCap
        ? messages.sublist(messages.length - _chatHistoryCap)
        : messages;
    return _data.put('chat_history', capped);
  }

  static Future<void> clearChat() => _data.delete('chat_history');

  // ----------------------- PRO cache -----------------------

  static bool isProCached() {
    try {
      final dynamic until = _data.get('pro_until');
      if (until is! String || until.isEmpty) return false;
      return DateTime.tryParse(until)?.isAfter(DateTime.now()) ?? false;
    } catch (_) {
      return false;
    }
  }

  static DateTime? proUntil() {
    try {
      final dynamic until = _data.get('pro_until');
      if (until is String) return DateTime.tryParse(until);
    } catch (_) {}
    return null;
  }

  static Future<void> setProUntil(DateTime? until) async {
    if (until == null) {
      await _data.delete('pro_until');
    } else {
      await _data.put('pro_until', until.toIso8601String());
    }
  }

  /// Boolean cache writer used by ProStatusNotifier.
  static Future<void> setProCached(bool value) async {
    if (value) {
      if (proUntil() == null ||
          (proUntil()?.isBefore(DateTime.now()) ?? true)) {
        await setProUntil(DateTime.now().add(const Duration(days: 31)));
      }
    } else {
      await setProUntil(null);
    }
  }

  // ----------------------- last sync marker -----------------------

  static DateTime? lastSyncAt() {
    try {
      final dynamic v = _data.get('last_sync_at');
      if (v is String) return DateTime.tryParse(v);
    } catch (_) {}
    return null;
  }

  static Future<void> setLastSyncAt(DateTime t) =>
      _data.put('last_sync_at', t.toIso8601String());

  // ----------------------- misc -----------------------

  /// Stable device uid for guest usage (kept in the settings box).
  static String guestUid() {
    String? uid = get<String>(settingsBox, 'guest_uid');
    if (uid == null || uid.isEmpty) {
      uid = 'guest_${DateTime.now().millisecondsSinceEpoch}';
      put(settingsBox, 'guest_uid', uid);
    }
    return uid;
  }
}
