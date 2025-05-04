import 'package:flutter/foundation.dart';

@immutable
class FcmConfig {
  final String projectId;
  final String serviceAccountJson;

  const FcmConfig({
    required this.projectId,
    required this.serviceAccountJson,
  });
}
