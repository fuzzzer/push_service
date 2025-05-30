import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../config/constants.dart';
import '../../../preferences/data/services/preferences_service.dart';

enum FcmSendStatus { initial, loading, success, validationSuccess, failure }

@immutable
class FcmSenderState {
  final PreferenceData? preferences;
  final bool preferencesLoaded;

  final String serviceAccountJson;
  final String projectId;
  final TargetType targetType;
  final TargetDevice targetDevice;
  final String targetValue;
  final String dataTitle;
  final String dataBody;
  final String dataDeepLink;
  final String additionalDataJson;
  final String analyticsLabel;
  final String androidPriority;
  final String apnsPriority;

  final FcmSendStatus sendStatus;
  final String statusMessage;
  final String logOutput;
  final String? lastResponseBody;

  const FcmSenderState({
    this.preferences,
    this.preferencesLoaded = false,
    this.serviceAccountJson = '',
    this.projectId = DEFAULT_PROJECT_ID,
    this.targetType = TargetType.token,
    this.targetDevice = TargetDevice.ios,
    this.targetValue = '',
    this.dataTitle = '',
    this.dataBody = '',
    this.dataDeepLink = '',
    this.additionalDataJson = '',
    this.analyticsLabel = '',
    this.androidPriority = 'DEFAULT',
    this.apnsPriority = 'DEFAULT',
    this.sendStatus = FcmSendStatus.initial,
    this.statusMessage = 'Idle',
    this.logOutput = '',
    this.lastResponseBody,
  });

  bool get isFormPotentiallyValid {
    if (serviceAccountJson.isEmpty || projectId.isEmpty) return false;
    if (targetType != TargetType.allChosenDevices && targetValue.isEmpty) return false;

    if (additionalDataJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(additionalDataJson);
        if (decoded is! Map) return false;
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  FcmSenderState copyWith({
    PreferenceData? preferences,
    bool? preferencesLoaded,
    String? serviceAccountJson,
    String? projectId,
    TargetType? targetType,
    TargetDevice? targetDevice,
    String? targetValue,
    String? dataTitle,
    String? dataBody,
    String? dataDeepLink,
    String? additionalDataJson,
    String? analyticsLabel,
    String? androidPriority,
    String? apnsPriority,
    FcmSendStatus? sendStatus,
    String? statusMessage,
    String? logOutput,
    String? lastResponseBody,
    bool clearLastResponseBody = false,
  }) {
    return FcmSenderState(
      preferences: preferences ?? this.preferences,
      preferencesLoaded: preferencesLoaded ?? this.preferencesLoaded,
      serviceAccountJson: serviceAccountJson ?? this.serviceAccountJson,
      projectId: projectId ?? this.projectId,
      targetType: targetType ?? this.targetType,
      targetDevice: targetDevice ?? this.targetDevice,
      targetValue: targetValue ?? this.targetValue,
      dataTitle: dataTitle ?? this.dataTitle,
      dataBody: dataBody ?? this.dataBody,
      dataDeepLink: dataDeepLink ?? this.dataDeepLink,
      additionalDataJson: additionalDataJson ?? this.additionalDataJson,
      analyticsLabel: analyticsLabel ?? this.analyticsLabel,
      androidPriority: androidPriority ?? this.androidPriority,
      apnsPriority: apnsPriority ?? this.apnsPriority,
      sendStatus: sendStatus ?? this.sendStatus,
      statusMessage: statusMessage ?? this.statusMessage,
      logOutput: logOutput ?? this.logOutput,
      lastResponseBody: clearLastResponseBody ? null : (lastResponseBody ?? this.lastResponseBody),
    );
  }
}
