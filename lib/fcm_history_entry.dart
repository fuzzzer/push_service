import 'package:hive/hive.dart';

part 'fcm_history_entry.g.dart'; // Hive generator will create this

@HiveType(typeId: 0) // Unique typeId for Hive
class FcmHistoryEntry extends HiveObject {
  @HiveField(0)
  late DateTime timestamp;

  @HiveField(1)
  late String targetType; // e.g., 'token', 'topic'

  @HiveField(2)
  late String targetValue; // The actual token or topic name

  @HiveField(3)
  late String payloadJson; // Store the sent data payload as a JSON string

  @HiveField(4)
  String? analyticsLabel; // Optional

  @HiveField(5)
  String? status; // Optional: e.g., 'Sent', 'Validated', 'Failed'

  @HiveField(6)
  String? responseBody; // Optional: Store the response from FCM API

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
