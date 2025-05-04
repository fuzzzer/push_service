import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:push_service/lib.dart';

class FcmSenderCubit extends Cubit<FcmSenderState> {
  final FcmRepositoryAndroid _fcmRepositoryAndroid;
  final FcmRepositoryIos _fcmRepositoryIos;
  final PreferencesService _preferencesService;
  final HistoryRepository _historyRepository;

  FcmSenderCubit({
    required FcmRepositoryAndroid fcmRepositoryAndroid,
    required FcmRepositoryIos fcmRepositoryIos,
    required PreferencesService preferencesService,
    required HistoryRepository historyRepository,
  })  : _fcmRepositoryAndroid = fcmRepositoryAndroid,
        _fcmRepositoryIos = fcmRepositoryIos,
        _preferencesService = preferencesService,
        _historyRepository = historyRepository,
        super(const FcmSenderState());

  Future<void> loadPreferences() async {
    try {
      final prefsData = await _preferencesService.loadPreferences();
      emit(
        state.copyWith(
          preferences: prefsData,
          preferencesLoaded: true,
          serviceAccountJson: prefsData.serviceAccountJson,
          projectId: prefsData.projectId,
          targetType: prefsData.targetType,
          targetValue: prefsData.targetValue,
          analyticsLabel: prefsData.analyticsLabel,
          androidPriority: prefsData.androidPriority,
          apnsPriority: prefsData.apnsPriority,
          statusMessage: 'Preferences Loaded',
        ),
      );
      _addToLog('Loaded saved preferences.');
    } catch (e) {
      emit(state.copyWith(statusMessage: 'Error loading preferences: $e'));
      _addToLog('Error loading preferences: $e');
    }
  }

  void updateServiceAccountJson(String value) {
    emit(state.copyWith(serviceAccountJson: value));
    _preferencesService.saveServiceAccountJson(value);
  }

  void updateProjectId(String value) {
    emit(state.copyWith(projectId: value));
    _preferencesService.saveProjectId(value);
  }

  void updateTargetType(TargetType type) {
    String newValue = state.targetValue;
    if (type == TargetType.all) {
      newValue = DEFAULT_ALL_DEVICES_TOPIC;
    } else if (state.targetType == TargetType.all) {
      newValue = '';
    }
    emit(state.copyWith(targetType: type, targetValue: newValue));
    _preferencesService.saveTarget(type: type, value: newValue);
  }

  void updateTargetValue(String value) {
    if (state.targetType != TargetType.all) {
      emit(state.copyWith(targetValue: value));
      _preferencesService.saveTarget(type: state.targetType, value: value);
    }
  }

  void updateDataTitle(String value) => emit(state.copyWith(dataTitle: value));
  void updateDataBody(String value) => emit(state.copyWith(dataBody: value));
  void updateDataDeepLink(String value) => emit(state.copyWith(dataDeepLink: value));
  void updateAdditionalDataJson(String value) => emit(state.copyWith(additionalDataJson: value));

  void updateAnalyticsLabel(String value) {
    emit(state.copyWith(analyticsLabel: value));
    _preferencesService.saveAnalyticsLabel(value);
  }

  void updateAndroidPriority(String value) {
    emit(state.copyWith(androidPriority: value));
    _preferencesService.saveAndroidPriority(value);
  }

  void updateApnsPriority(String value) {
    emit(state.copyWith(apnsPriority: value));
    _preferencesService.saveApnsPriority(value);
  }

  void _addToLog(String message) {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
    final newLog = '$state.logOutput[$timestamp] $message\n';

    emit(state.copyWith(logOutput: newLog));
  }

  void clearLog() {
    emit(state.copyWith(logOutput: ''));
  }

  Future<void> sendFcm({required bool validateOnly}) async {
    clearLog();
    _addToLog('Starting request... (Validate Only: $validateOnly)');
    emit(
      state.copyWith(
        sendStatus: FcmSendStatus.loading,
        statusMessage: validateOnly ? 'Validating...' : 'Sending...',
        clearLastResponseBody: true,
      ),
    );

    if (state.serviceAccountJson.isEmpty || state.projectId.isEmpty) {
      emit(
        state.copyWith(
          sendStatus: FcmSendStatus.failure,
          statusMessage: 'Error: Project ID and Service Account JSON are required.',
        ),
      );
      _addToLog('Validation failed: Missing Project ID or Service Account JSON.');
      return;
    }
    if (state.targetType != TargetType.all && state.targetValue.isEmpty) {
      emit(
        state.copyWith(
          sendStatus: FcmSendStatus.failure,
          statusMessage: 'Error: Target Token or Topic Name is required.',
        ),
      );
      _addToLog('Validation failed: Missing Target Value for selected type.');
      return;
    }

    final config = FcmConfig(
      projectId: state.projectId,
      serviceAccountJson: state.serviceAccountJson,
    );

    final messageData = FcmMessageData(
      targetType: state.targetType,
      targetDevice: state.targetDevice,
      targetValue: state.targetValue,
      titleOverride: state.dataTitle,
      bodyOverride: state.dataBody,
      deepLinkOverride: state.dataDeepLink,
      additionalDataJson: state.additionalDataJson,
      analyticsLabel: state.analyticsLabel,
      androidPriority: state.androidPriority,
      apnsPriority: state.apnsPriority,
    );

    _addToLog('Project ID: ${config.projectId}');
    _addToLog('Target Type: ${state.targetType}');
    _addToLog('Target Value: ${messageData.targetValue}');
    if (messageData.analyticsLabel != null && messageData.analyticsLabel!.isNotEmpty) {
      _addToLog('Analytics Label: ${messageData.analyticsLabel}');
    }
    if (messageData.androidPriority != null && messageData.androidPriority != 'DEFAULT') {
      _addToLog('Android Priority: ${messageData.androidPriority}');
    }
    if (messageData.apnsPriority != null && messageData.apnsPriority != 'DEFAULT') {
      _addToLog('APNS Priority: ${messageData.apnsPriority}');
    }
    _addToLog('Additional Data JSON: ${messageData.additionalDataJson ?? '(empty)'}');

    final SendFcmResponse response;

    if (messageData.targetDevice == TargetDevice.android) {
      response = await _fcmRepositoryAndroid.sendFcm(
        config: config,
        messageData: messageData,
        validateOnly: validateOnly,
      );
    } else {
      response = await _fcmRepositoryIos.sendFcm(
        config: config,
        messageData: messageData,
        validateOnly: validateOnly,
      );
    }

    String finalPayloadJson = '{}';
    try {
      Map<String, String> finalDataPayload = {};
      if (messageData.additionalDataJson != null && messageData.additionalDataJson!.trim().isNotEmpty) {
        final parsedJson = jsonDecode(messageData.additionalDataJson!);
        if (parsedJson is Map) {
          finalDataPayload = parsedJson.map((key, value) => MapEntry(key.toString(), value.toString()));
        }
      }
      if (messageData.titleOverride != null && messageData.titleOverride!.isNotEmpty) {
        finalDataPayload['title'] = messageData.titleOverride!;
      }
      if (messageData.bodyOverride != null && messageData.bodyOverride!.isNotEmpty) {
        finalDataPayload['body'] = messageData.bodyOverride!;
      }
      if (messageData.deepLinkOverride != null && messageData.deepLinkOverride!.isNotEmpty) {
        finalDataPayload['deepLink'] = messageData.deepLinkOverride!;
      }
      finalPayloadJson = jsonEncode(finalDataPayload);
    } catch (e) {
      _addToLog('Warning: Could not reconstruct final payload for history due to JSON error: $e');
    }

    switch (response) {
      case SendFcmSuccess(:final responseBody, :final wasValidation):
        final successMessage = wasValidation ? 'Validation Success!' : 'Send Success!';
        emit(
          state.copyWith(
            sendStatus: wasValidation ? FcmSendStatus.validationSuccess : FcmSendStatus.success,
            statusMessage: successMessage,
            lastResponseBody: responseBody,
          ),
        );
        _addToLog('--- FCM API Call Completed ---');
        _addToLog('Status: $successMessage');
        _addToLog('Response Body:\n${_formatJson(responseBody)}');
        await _saveToHistory(
          messageData: messageData,
          finalPayloadJson: finalPayloadJson,
          status: successMessage,
          responseBody: responseBody,
        );

      case SendFcmFailure(
          :final message,
          :final requestBodyAttempted,
          :final responseBody,
          :final error,
          :final stackTrace
        ):
        emit(
          state.copyWith(
            sendStatus: FcmSendStatus.failure,
            statusMessage: 'Error: $message',
            lastResponseBody: responseBody ?? 'No response body available.',
          ),
        );
        _addToLog('--- FCM API Call Failed ---');
        _addToLog('Error: $message');
        if (responseBody != null) _addToLog('FCM Response Body (Error):\n${_formatJson(responseBody)}');
        if (requestBodyAttempted != null) {
          _addToLog('Request Body Sent/Attempted:\n${_formatJson(requestBodyAttempted)}');
        }
        if (error != null) _addToLog('Underlying Error: $error');
        if (stackTrace != null) _addToLog('Stack Trace:\n$stackTrace');
        await _saveToHistory(
          messageData: messageData,
          finalPayloadJson: finalPayloadJson,
          status: 'Failure: $message',
          responseBody: responseBody ?? 'Client Error: $error',
        );
    }
  }

  Future<void> _saveToHistory({
    required FcmMessageData messageData,
    required String finalPayloadJson,
    required String status,
    String? responseBody,
  }) async {
    try {
      final entry = FcmHistoryEntry(
        timestamp: DateTime.now(),
        targetType: messageData.targetType.name,
        targetValue: messageData.targetValue,
        payloadJson: finalPayloadJson,
        analyticsLabel: messageData.analyticsLabel,
        status: status,
        responseBody: responseBody,
      );
      await _historyRepository.saveHistoryEntry(entry);
      _addToLog('Saved send attempt to history.');
    } catch (e) {
      _addToLog('Error saving to history: $e');

      emit(state.copyWith(statusMessage: '${state.statusMessage}\n(Failed to save history)'));
    }
  }

  String _formatJson(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return '(empty)';
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(jsonDecode(jsonString));
    } catch (e) {
      return jsonString;
    }
  }
}
