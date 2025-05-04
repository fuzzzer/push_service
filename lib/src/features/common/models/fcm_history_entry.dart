import 'package:hive/hive.dart';

part 'fcm_history_entry.g.dart';

@HiveType(typeId: 0)
class FcmHistoryEntry extends HiveObject {
  @HiveField(0)
  late DateTime timestamp;

  @HiveField(1)
  late String targetType;

  @HiveField(2)
  late String targetValue;

  @HiveField(3)
  late String payloadJson;

  @HiveField(4)
  String? analyticsLabel;

  @HiveField(5)
  String? status;

  @HiveField(6)
  String? responseBody;

  FcmHistoryEntry({
    required this.timestamp,
    required this.targetType,
    required this.targetValue,
    required this.payloadJson,
    this.analyticsLabel,
    this.status,
    this.responseBody,
  });
}
