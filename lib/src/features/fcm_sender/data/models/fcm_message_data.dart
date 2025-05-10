import 'package:flutter/foundation.dart';
import '../../../../config/constants.dart'; // For TargetType

@immutable
class FcmMessageData {
  final TargetType targetType;
  final TargetDevice targetDevice;
  final String targetValue; // Actual token or topic name
  final String? title;
  final String? body;
  final String? deepLink;
  final String? additionalDataJson; // Raw JSON string for additional data
  final String? analyticsLabel;
  final String? androidPriority; // 'NORMAL', 'HIGH', or null for default
  final String? apnsPriority; // '5', '10', or null for default

  const FcmMessageData({
    required this.targetType,
    required this.targetDevice,
    required this.targetValue,
    this.title,
    this.body,
    this.deepLink,
    this.additionalDataJson,
    this.analyticsLabel,
    this.androidPriority,
    this.apnsPriority,
  });
}
