// GENERATED CODE - DO NOT MODIFY BY HAND
// (Hand-maintained to match Hive's generator output; keeps the build simple.)

part of 'user.dart';

// **************************************************************************
// UserAdapter
// **************************************************************************

class UserAdapter extends TypeAdapter<User> {
  @override
  final int typeId = 10;

  @override
  User read(BinaryReader reader) {
    final int numOfFields = reader.readByte();
    final Map<int, dynamic> fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return User(
      uid: (fields[0] ?? '') as String,
      name: (fields[1] ?? 'مستخدم') as String,
      email: (fields[2] ?? '') as String,
      isGuest: (fields[3] ?? false) as bool,
      isPro: (fields[4] ?? false) as bool,
      proUntil: fields[5] as String?,
      currency: (fields[6] ?? 'ج.م') as String,
    )..isPro = (fields[4] ?? false) as bool;
  }

  @override
  void write(BinaryWriter writer, User obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.uid)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.isGuest)
      ..writeByte(4)
      ..write(obj.isPro)
      ..writeByte(5)
      ..write(obj.proUntil)
      ..writeByte(6)
      ..write(obj.currency);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId);
}
