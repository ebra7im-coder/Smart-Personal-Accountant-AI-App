// GENERATED CODE - DO NOT MODIFY BY HAND
// (Hand-maintained to match Hive's generator output; keeps the build simple.)

part of 'budget.dart';

// **************************************************************************
// BudgetAdapter
// **************************************************************************

class BudgetAdapter extends TypeAdapter<Budget> {
  @override
  final int typeId = 11;

  @override
  Budget read(BinaryReader reader) {
    final int numOfFields = reader.readByte();
    final Map<int, dynamic> fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Budget(
      category: (fields[0] ?? 'other') as String,
      limit: (fields[1] as num?)?.toDouble() ?? 0.0,
      monthKey: (fields[2] ?? '') as String,
    );
  }

  @override
  void write(BinaryWriter writer, Budget obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.category)
      ..writeByte(1)
      ..write(obj.limit)
      ..writeByte(2)
      ..write(obj.monthKey);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BudgetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId);
}
