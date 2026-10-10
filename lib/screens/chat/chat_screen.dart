// AI Chat Accountant — full chat screen with the CodeCraft / claude-opus-5.5
// backend. The AI receives a live summary of the user's transactions as part
// of the system prompt, so answers like "كم صرفت على المطاعم الشهر ده؟" are
// grounded in real data.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../models/chat_message.dart';
import '../../models/transaction.dart';
import '../../providers/plan_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/ai_service.dart';
import '../../services/hive_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';

/// Free users get a daily AI message quota; PRO is unlimited.
class ChatQuota {
  static const int freeDailyMessages = 15;

  static String dayKey() => Helpers.dayKey(DateTime.now());

  static int usedToday() {
    final dynamic v = HiveService.get<dynamic>(
        HiveService.settingsBox, 'chat_used_${dayKey()}');
    return v is int ? v : 0;
  }

  static Future<void> increment() async {
    await HiveService.put(
        HiveService.settingsBox, 'chat_used_${dayKey()}', usedToday() + 1);
  }

  static bool get isBlocked => usedToday() >= freeDailyMessages;
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final SpeechToText _speech = SpeechToText();

  final List<ChatMessage> _messages = <ChatMessage>[];
  final List<AiChatTurn> _history = <AiChatTurn>[];

  bool _sending = false;
  bool _listening = false;

  static const List<String> _quickQuestions = <String>[
    'كم صرفت على المطاعم الشهر ده؟',
    'إزاي أوفر ٢٠٪ من مرتبي؟',
    'أكتر تصنيف بحرقه إيه؟',
    'لخصلي مصاريف الشهر',
  ];

  @override
  void initState() {
    super.initState();
    HiveService.purgeOldChatQuotaKeys(ChatQuota.dayKey());
    _loadHistory();
  }

  void _loadHistory() {
    final List<ChatMessage> saved = HiveService.loadChat();
    if (saved.isEmpty) {
      _messages.add(ChatMessage(
        id: 'welcome',
        text: 'أهلاً يا صديقي 👋 أنا محاسبك الشخصي.\n'
            'اسألني أي حاجة عن فلوسك: صرفت كام؟ أوفر منين؟ '
            'أنا شايف كل معاملاتك وبحللها لك.',
        role: 'assistant',
        createdAt: DateTime.now(),
      ));
    } else {
      _messages.addAll(saved);
      for (final ChatMessage m in saved) {
        _history.add(AiChatTurn(
          role: m.isUser ? 'user' : 'assistant',
          content: m.text,
        ));
      }
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // --------------------------------------------------------------- context

  /// Builds the financial summary injected into the system prompt.
  String _buildContext() {
    final (double income, double expense, _) = (
      ref.read(monthTotalsProvider).income,
      ref.read(monthTotalsProvider).expense,
      ref.read(monthTotalsProvider).balance,
    );
    final List<Transaction> all = ref.read(transactionListProvider);
    final String mk = Helpers.monthKey(DateTime.now());
    final Map<String, double> byCategory = <String, double>{};
    for (final Transaction t in all) {
      if (t.type != TxType.expense || t.monthKey() != mk) continue;
      byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amount;
    }
    final List<({String title, double amount})> top = all
        .where((Transaction t) => t.type == TxType.expense)
        .take(5)
        .map((Transaction t) => (
              title: t.note.isEmpty ? t.category.arLabel : t.note,
              amount: t.amount,
            ))
        .toList();

    return AiService.buildTransactionsSummary(
      monthIncome: income,
      monthExpense: expense,
      expensesByCategory: byCategory,
      topExpenses: top,
    );
  }

  // --------------------------------------------------------------- send

  Future<void> _send(String text) async {
    final String trimmed = text.trim();
    if (trimmed.isEmpty || _sending) return;

    // Free-plan quota (PRO = unlimited).
    if (!ref.read(isProProvider) && ChatQuota.isBlocked) {
      Fluttertoast.showToast(
        msg:
            'خلصت رسايل الـ AI النهاردة (١٥) — قم بالترقية إلى PRO للمحادثة بلا حدود',
        toastLength: Toast.LENGTH_LONG,
      );
      return;
    }

    _inputCtrl.clear();
    final ChatMessage userMsg = ChatMessage(
      id: 'm_${DateTime.now().millisecondsSinceEpoch}_u',
      text: trimmed,
      role: 'user',
      createdAt: DateTime.now(),
    );
    final ChatMessage pending = ChatMessage(
      id: 'm_${DateTime.now().millisecondsSinceEpoch}_a',
      text: '',
      role: 'assistant',
      createdAt: DateTime.now(),
      pending: true,
    );
    setState(() {
      _messages.addAll(<ChatMessage>[userMsg, pending]);
      _sending = true;
    });
    _history.add(AiChatTurn(role: 'user', content: trimmed));
    _scrollToBottom();

    try {
      final String reply = await AiService.instance.chatWithAccountant(
        userMessage: trimmed,
        history: _history.sublist(
            0, _history.length - 1), // current question sent separately
        transactionsSummary: _buildContext(),
      );
      _updatePending(reply);
      _history.add(AiChatTurn(role: 'assistant', content: reply));
      if (!ref.read(isProProvider)) await ChatQuota.increment();
    } on AiNotConfiguredException {
      _updatePending(
          'خدمة الـ AI مش مهيأة على الجهاز ده. المطور لازم يضيف مفتاح '
          'CODECRAFT_API_KEY عند البناء (--dart-define).',
          isError: true);
    } catch (_) {
      _updatePending(
          'تعذر الاتصال بالذكاء الاصطناعي 😔 — اضغط هنا لإعادة المحاولة',
          isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// In-memory retry texts for error bubbles (id -> original user message).
  final Map<String, String> _retryTexts = <String, String>{};

  void _updatePending(String text, {bool isError = false}) {
    final int idx = _messages.indexWhere((ChatMessage m) => m.pending);
    if (idx == -1) return;
    setState(() {
      _messages[idx] =
          _messages[idx].copyWith(text: text, pending: false, isError: isError);
    });
    if (isError) _retryTexts[_messages[idx].id] = text;
    HiveService.saveChat(
        _messages.where((ChatMessage m) => m.id != 'welcome').toList());
    _scrollToBottom();
  }

  /// Tap on an error bubble -> resend the original question.
  Future<void> _retry(ChatMessage errorMsg) async {
    final String? question = _retryTexts[errorMsg.id];
    setState(() {
      _messages.remove(errorMsg);
      _retryTexts.remove(errorMsg.id);
      // Drop the trailing user turn so it is not duplicated.
      if (_history.isNotEmpty && _history.last.role == 'user') {
        _history.removeLast();
      }
    });
    if (question == null || question.isEmpty) {
      Fluttertoast.showToast(msg: 'أعد كتابة رسالتك من فضلك');
      return;
    }
    await _send(question);
  }

  // --------------------------------------------------------------- voice

  Future<void> _toggleMic() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    try {
      final bool ok = await _speech.initialize();
      if (!ok) {
        Fluttertoast.showToast(msg: 'الميكروفون غير متاح');
        return;
      }
      setState(() => _listening = true);
      await _speech.listen(
        localeId: 'ar',
        listenOptions: SpeechListenOptions(partialResults: false),
        onResult: (dynamic result) {
          if (!mounted) return;
          setState(() => _listening = false);
          final String words = result.recognizedWords ?? '';
          if ((result.finalResult == true) && words.trim().isNotEmpty) {
            _send(words);
          }
        },
      );
    } catch (_) {
      if (mounted) setState(() => _listening = false);
      Fluttertoast.showToast(msg: 'تعذر تشغيل الميكروفون');
    }
  }

  // --------------------------------------------------------------- UI

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    try {
      _speech.stop();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        title: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.green,
              child: ref.watch(isProProvider)
                  ? const Icon(Icons.workspace_premium_rounded,
                      size: 17, color: AppColors.white)
                  : const Icon(Icons.auto_awesome,
                      size: 16, color: AppColors.white),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('المحاسب الآلي',
                    style: TextStyle(fontSize: 15, color: AppColors.white)),
                Text(
                  'متصل • بيشوف معاملاتك الحقيقية',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'محادثة جديدة',
            onPressed: () async {
              await HiveService.clearChat();
              setState(() {
                _messages.clear();
                _history.clear();
                _loadHistory();
              });
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(14),
              itemCount: _messages.length + (_messages.length <= 1 ? 1 : 0),
              itemBuilder: (BuildContext ctx, int i) {
                if (_messages.length <= 1 && i == 0) {
                  return _QuickQuestions(
                    questions: _quickQuestions,
                    onTap: _send,
                  );
                }
                final int idx = _messages.length <= 1 ? i - 1 : i;
                final ChatMessage msg = _messages[idx];
                return _Bubble(
                  message: msg,
                  onTap: msg.isError ? () => _retry(msg) : null,
                );
              },
            ),
          ),
          _InputBar(
            controller: _inputCtrl,
            sending: _sending,
            listening: _listening,
            onSend: _send,
            onMic: _toggleMic,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.onTap});

  final ChatMessage message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool isUser = message.isUser;
    return Align(
      alignment: isUser
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            color: isUser
                ? AppColors.navy
                : (message.isError ? AppColors.redSoft : AppColors.white),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
            border: isUser
                ? null
                : Border.all(
                    color: message.isError
                        ? AppColors.danger.withOpacity(0.4)
                        : AppColors.line),
          ),
          child: message.pending
              ? const _TypingDots()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SelectableText(
                      message.text,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        color: isUser
                            ? AppColors.white
                            : (message.isError
                                ? AppColors.danger
                                : AppColors.textDark),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('hh:mm a', 'ar').format(message.createdAt),
                      style: TextStyle(
                        fontSize: 9,
                        color: isUser
                            ? AppColors.white.withOpacity(0.6)
                            : AppColors.textHint,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext ctx, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(3, (int i) {
            final double phase = (_c.value * 3 - i).clamp(0.0, 1.0);
            final double dy = (1 - (2 * phase - 1).abs()) * 4;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 7,
              height: 7,
              transform: Matrix4.translationValues(0, -dy, 0),
              decoration: const BoxDecoration(
                color: AppColors.textHint,
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

class _QuickQuestions extends StatelessWidget {
  const _QuickQuestions({required this.questions, required this.onTap});

  final List<String> questions;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: questions
          .map((String q) => ActionChip(
                backgroundColor: AppColors.white,
                side: const BorderSide(color: AppColors.line),
                label: Text(q, style: const TextStyle(fontSize: 12)),
                onPressed: () => onTap(q),
              ))
          .toList(),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.sending,
    required this.listening,
    required this.onSend,
    required this.onMic,
  });

  final TextEditingController controller;
  final bool sending;
  final bool listening;
  final ValueChanged<String> onSend;
  final VoidCallback onMic;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: onSend,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'اسأل محاسبك الآلي...',
                  filled: true,
                  fillColor: AppColors.bg,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onMic,
              child: CircleAvatar(
                radius: 21,
                backgroundColor: listening ? AppColors.green : AppColors.bg,
                child: Icon(
                  listening ? Icons.stop_rounded : Icons.mic_rounded,
                  size: 20,
                  color: listening ? AppColors.white : AppColors.navy,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: sending ? null : () => onSend(controller.text),
              child: CircleAvatar(
                radius: 21,
                backgroundColor: sending ? AppColors.line : AppColors.green,
                child: sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.white),
                      )
                    : const Icon(Icons.send_rounded,
                        size: 19, color: AppColors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
