// GENERATED CODE - DO NOT MODIFY BY HAND
// (Hand-maintained to match Hive's generator output; keeps the build simple.)

part of 'transaction.dart';

// **************************************************************************
// TxTypeAdapter
// **************************************************************************

class TxTypeAdapter extends TypeAdapter<TxType> {
  @override
  final int typeId = 1;

  @override
  TxType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TxType.income;
      case 1:
        return TxType.expense;
      default:
        return TxType.income;
    }
  }

  @override
  void write(BinaryWriter writer, TxType obj) {
    switch (obj) {
      case TxType.income:
        writer.writeByte(0);
      case TxType.expense:
        writer.writeByte(1);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TxTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId);
}

// **************************************************************************
// TransactionAdapter
// **************************************************************************

class TransactionAdapter extends TypeAdapter<Transaction> {
  @override
  final int typeId = 0;

  @override
  Transaction read(BinaryReader reader) {
    final int numOfFields = reader.readByte();
    final Map<int, dynamic> fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Transaction(
      id: (fields[0] ?? '') as String,
      type: (fields[1] as TxType?) ?? TxType.expense,
      category: (fields[2] ?? 'other') as String,
      amount: (fields[3] as num?)?.toDouble() ?? 0.0,
      date: (fields[4] as DateTime?) ?? DateTime.fromMillisecondsSinceEpoch(0),
      note: (fields[5] ?? '') as String,
      createdAtMs: (fields[6] as num?)?.toInt() ?? 0,
      source: (fields[7] ?? 'manual') as String,
      synced: (fields[8] ?? false) as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Transaction obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.note)
      ..writeByte(6)
      ..write(obj.createdAtMs)
      ..writeByte(7)
      ..write(obj.source)
      ..writeByte(8)
      ..write(obj.synced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId);
}
