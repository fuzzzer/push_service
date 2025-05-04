import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

import '../../../../config/constants.dart';
import '../models/fcm_config.dart';
import '../models/fcm_message_data.dart';
import '../models/fcm_send_response.dart';

class FcmRepositoryIos {
  final http.Client httpClient;

  FcmRepositoryIos({required this.httpClient});

  Future<String?> _getAccessToken(String serviceAccountJson) async {
    if (serviceAccountJson.isEmpty) {
      return null;
    }
    try {
      final credentialsJson = jsonDecode(serviceAccountJson);
      final credentials = ServiceAccountCredentials.fromJson(credentialsJson);
      final accessCredentials = await obtainAccessCredentialsViaServiceAccount(
        credentials,
        FCM_SCOPES,
        httpClient,
      );
      return accessCredentials.accessToken.data;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting access token: $e');
      }
      return null;
    }
  }

  Future<SendFcmResponse> sendFcm({
    required FcmConfig config,
    required FcmMessageData messageData,
    required bool validateOnly,
  }) async {
    String? requestBodyString;
    String? apiTargetType;
    String? apiTargetValue;

    try {
      final accessToken = await _getAccessToken(config.serviceAccountJson);
      if (accessToken == null) {
        return SendFcmFailure(message: 'Failed to obtain Google Access Token. Check Service Account JSON.');
      }

      switch (messageData.targetType) {
        case TargetType.token:
          apiTargetType = 'token';
          apiTargetValue = messageData.targetValue;
        case TargetType.topic:
        case TargetType.all:
          apiTargetType = 'topic';

          apiTargetValue = messageData.targetValue.startsWith('/topics/')
              ? messageData.targetValue.substring('/topics/'.length)
              : messageData.targetValue;
      }

      if (apiTargetValue.isEmpty) {
        return SendFcmFailure(message: 'Invalid target configuration: Type or Value is missing.');
      }

      Map<String, String> finalDataPayload = {};
      if (messageData.additionalDataJson != null && messageData.additionalDataJson!.trim().isNotEmpty) {
        try {
          final parsedJson = jsonDecode(messageData.additionalDataJson!);
          if (parsedJson is Map) {
            finalDataPayload = parsedJson.map((key, value) => MapEntry(key.toString(), value.toString()));
          } else {
            return SendFcmFailure(message: 'Invalid JSON structure in Additional Data: Must be a JSON object (Map).');
          }
        } catch (e) {
          return SendFcmFailure(message: 'Invalid JSON format in Additional Data: $e');
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

      if (finalDataPayload.isEmpty && !validateOnly) {
        return SendFcmFailure(message: 'Resulting data payload is empty. Cannot send.');
      }

      final Map<String, dynamic> message = {
        apiTargetType: apiTargetValue,
        'data': finalDataPayload,
      };

      final Map<String, dynamic> androidConfig = {};
      if (messageData.androidPriority != null && messageData.androidPriority != 'DEFAULT') {
        androidConfig['priority'] = messageData.androidPriority;
      }
      if (androidConfig.isNotEmpty) message['android'] = androidConfig;

      final Map<String, dynamic> apnsConfig = {};
      final Map<String, String> apnsHeaders = {};
      if (messageData.apnsPriority != null && messageData.apnsPriority != 'DEFAULT') {
        apnsHeaders['apns-priority'] = messageData.apnsPriority!;
      }
      if (apnsHeaders.isNotEmpty) apnsConfig['headers'] = apnsHeaders;
      if (apnsConfig.isNotEmpty) message['apns'] = apnsConfig;

      final Map<String, dynamic> fcmOptions = {};
      if (messageData.analyticsLabel != null && messageData.analyticsLabel!.isNotEmpty) {
        fcmOptions['analytics_label'] = messageData.analyticsLabel;
      }
      if (fcmOptions.isNotEmpty) message['fcm_options'] = fcmOptions;

      final Map<String, dynamic> requestBody = {'message': message};
      if (validateOnly) requestBody['validate_only'] = true;

      requestBodyString = jsonEncode(requestBody);

      final url = Uri.parse(FCM_SEND_URL.replaceFirst('{projectId}', config.projectId));
      final headers = {'Authorization': 'Bearer $accessToken', 'Content-Type': 'application/json'};

      final response = await httpClient.post(url, headers: headers, body: requestBodyString);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return SendFcmSuccess(
          responseBody: response.body,
          wasValidation: validateOnly,
        );
      } else {
        return SendFcmFailure(
          message: 'FCM API Error: Status Code ${response.statusCode}',
          requestBodyAttempted: requestBodyString,
          responseBody: response.body,
        );
      }
    } catch (e, s) {
      if (kDebugMode) {
        print('FCM Repository Error: $e\nStack: $s');
      }
      return SendFcmFailure(
        message: 'An unexpected error occurred: $e',
        requestBodyAttempted: requestBodyString,
        error: e,
        stackTrace: s,
      );
    }
  }
}
