// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fcm_history_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FcmHistoryEntryAdapter extends TypeAdapter<FcmHistoryEntry> {
  @override
  final int typeId = 0;

  @override
  FcmHistoryEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FcmHistoryEntry(
      timestamp: fields[0] as DateTime,
      targetType: fields[1] as String,
      targetValue: fields[2] as String,
      payloadJson: fields[3] as String,
      analyticsLabel: fields[4] as String?,
      status: fields[5] as String?,
      responseBody: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, FcmHistoryEntry obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.timestamp)
      ..writeByte(1)
      ..write(obj.targetType)
      ..writeByte(2)
      ..write(obj.targetValue)
      ..writeByte(3)
      ..write(obj.payloadJson)
      ..writeByte(4)
      ..write(obj.analyticsLabel)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.responseBody);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FcmHistoryEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
