import 'package:hive/hive.dart';

part 'chat_message.g.dart';

/// One message inside the AI Accountant chat screen.
@HiveType(typeId: 12)
class ChatMessage extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String text;

  /// `user` or `assistant`.
  @HiveField(2)
  final String role;

  @HiveField(3)
  final DateTime createdAt;

  /// Marks an in-flight assistant bubble (shows the typing indicator).
  @HiveField(4)
  bool pending;

  /// Marks a failed assistant bubble (tap to retry).
  @HiveField(5)
  bool isError;

  ChatMessage({
    required this.id,
    required this.text,
    required this.role,
    required this.createdAt,
    this.pending = false,
    this.isError = false,
  });

  bool get isUser => role == 'user';

  ChatMessage copyWith({String? text, bool? pending, bool? isError}) =>
      ChatMessage(
        id: id,
        text: text ?? this.text,
        role: role,
        createdAt: createdAt,
        pending: pending ?? this.pending,
        isError: isError ?? this.isError,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'text': text,
        'role': role,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
        id: (map['id'] ?? '') as String,
        text: (map['text'] ?? '') as String,
        role: (map['role'] ?? 'assistant') as String,
        createdAt: DateTime.tryParse((map['createdAt'] ?? '') as String) ??
            DateTime.now(),
      );
}
