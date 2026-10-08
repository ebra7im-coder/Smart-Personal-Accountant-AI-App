// GENERATED CODE - DO NOT MODIFY BY HAND
// (Hand-maintained to match Hive's generator output; keeps the build simple.)

part of 'chat_message.dart';

// **************************************************************************
// ChatMessageAdapter
// **************************************************************************

class ChatMessageAdapter extends TypeAdapter<ChatMessage> {
  @override
  final int typeId = 12;

  @override
  ChatMessage read(BinaryReader reader) {
    final int numOfFields = reader.readByte();
    final Map<int, dynamic> fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatMessage(
      id: (fields[0] ?? '') as String,
      text: (fields[1] ?? '') as String,
      role: (fields[2] ?? 'assistant') as String,
      createdAt: (fields[3] as DateTime?) ?? DateTime.now(),
    )..pending = (fields[4] ?? false) as bool;
  }

  @override
  void write(BinaryWriter writer, ChatMessage obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.text)
      ..writeByte(2)
      ..write(obj.role)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.pending);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatMessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId);
}
