import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

import '../../../../config/constants.dart';
import '../models/fcm_config.dart';

import '../models/fcm_message_data.dart';
import '../models/fcm_send_response.dart';

class FcmRepositoryAndroid {
  final http.Client _httpClient;

  FcmRepositoryAndroid({required http.Client httpClient}) : _httpClient = httpClient;

  Future<SendFcmResponse> sendFcm({
    required FcmConfig config,
    required FcmMessageData messageData,
    required bool validateOnly,
  }) async {
    String? encodedRequestBody;

    try {
      final String? accessToken = await _getAccessToken(config.serviceAccountJson);
      if (accessToken == null) {
        return SendFcmFailure(message: 'Authentication failed: Could not obtain Google Access Token.');
      }

      final Map<String, String>? apiTarget = _determineApiTarget(messageData);
      if (apiTarget == null) {
        return SendFcmFailure(message: 'Configuration error: Invalid target.');
      }
      final String apiTargetType = apiTarget['type']!;
      final String apiTargetValue = apiTarget['value']!;

      final Map<String, String> dataPayload = _buildDataPayload(messageData);

      if (dataPayload.isEmpty && !validateOnly) {
        return SendFcmFailure(message: 'Validation error: Data payload is empty.');
      }

      final Map<String, dynamic> requestBodyMap = _buildCompleteRequestBodyMap(
        apiTargetType: apiTargetType,
        apiTargetValue: apiTargetValue,
        dataPayload: dataPayload,
        messageData: messageData,
        validateOnly: validateOnly,
      );
      encodedRequestBody = jsonEncode(requestBodyMap);

      print('print $requestBodyMap');

      final Uri requestUrl = _buildRequestUrl(config.projectId);
      final Map<String, String> requestHeaders = _buildRequestHeaders(accessToken);
      final http.Response response = await _executeFcmRequest(
        url: requestUrl,
        headers: requestHeaders,
        body: encodedRequestBody,
      );

      return _processFcmResponse(response, validateOnly, encodedRequestBody);
    } on FormatException catch (e) {
      if (kDebugMode) print('FCM Payload JSON Error: $e');
      return SendFcmFailure(
        message: 'Data Payload Error: Invalid JSON format. $e',
        requestBodyAttempted: encodedRequestBody,
        error: e,
      );
    } catch (e, s) {
      if (kDebugMode) print('FCM Repository Unhandled Error: $e\nStack: $s');
      return SendFcmFailure(
        message: 'An unexpected error occurred: $e',
        requestBodyAttempted: encodedRequestBody,
        error: e,
        stackTrace: s,
      );
    }
  }

  Map<String, dynamic> _buildCompleteRequestBodyMap({
    required String apiTargetType,
    required String apiTargetValue,
    required Map<String, String> dataPayload,
    required FcmMessageData messageData,
    required bool validateOnly,
  }) {
    return {
      if (validateOnly) 'validate_only': true,
      'message': {
        apiTargetType: apiTargetValue,
        'data': dataPayload,
        if (messageData.androidPriority != null && messageData.androidPriority != 'DEFAULT')
          'android': {
            'priority': messageData.androidPriority,
          },
        if (messageData.apnsPriority != null && messageData.apnsPriority != 'DEFAULT')
          'apns': {
            'headers': {
              'apns-priority': messageData.apnsPriority!,
            },
          },
        if (messageData.analyticsLabel != null && messageData.analyticsLabel!.isNotEmpty)
          'fcm_options': {
            'analytics_label': messageData.analyticsLabel!,
          },
      },
    };
  }

  Future<String?> _getAccessToken(String serviceAccountJson) async {
    if (serviceAccountJson.isEmpty) {
      if (kDebugMode) print('FCM Auth Error: Service Account JSON is empty.');
      return null;
    }
    try {
      final credentialsJson = jsonDecode(serviceAccountJson);
      final credentials = ServiceAccountCredentials.fromJson(credentialsJson);
      final accessCredentials = await obtainAccessCredentialsViaServiceAccount(
        credentials,
        FCM_SCOPES,
        _httpClient,
      );
      return accessCredentials.accessToken.data;
    } catch (e) {
      if (kDebugMode) print('FCM Auth Error: Failed to get access token. Error: $e');
      return null;
    }
  }

  Map<String, String>? _determineApiTarget(FcmMessageData messageData) {
    String apiTargetType;
    String apiTargetValue;
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
      if (kDebugMode) print('FCM Config Error: Target value is empty for type ${messageData.targetType}.');
      return null;
    }
    return {'type': apiTargetType, 'value': apiTargetValue};
  }

  Map<String, String> _buildDataPayload(FcmMessageData messageData) {
    Map<String, String> payload = {};
    if (messageData.additionalDataJson != null && messageData.additionalDataJson!.trim().isNotEmpty) {
      final dynamic parsedJson = jsonDecode(messageData.additionalDataJson!);
      if (parsedJson is Map) {
        payload = parsedJson.map((key, value) => MapEntry(key.toString(), value.toString()));
      } else {
        throw const FormatException('Invalid JSON structure: Additional Data must be an object.');
      }
    }
    if (messageData.titleOverride != null && messageData.titleOverride!.isNotEmpty) {
      payload['title'] = messageData.titleOverride!;
    }
    if (messageData.bodyOverride != null && messageData.bodyOverride!.isNotEmpty) {
      payload['body'] = messageData.bodyOverride!;
    }
    if (messageData.deepLinkOverride != null && messageData.deepLinkOverride!.isNotEmpty) {
      payload['deepLink'] = messageData.deepLinkOverride!;
    }
    return payload;
  }

  Uri _buildRequestUrl(String projectId) {
    final urlString = FCM_SEND_URL.replaceFirst('{projectId}', projectId);
    return Uri.parse(urlString);
  }

  Map<String, String> _buildRequestHeaders(String accessToken) {
    return {'Authorization': 'Bearer $accessToken', 'Content-Type': 'application/json'};
  }

  Future<http.Response> _executeFcmRequest({
    required Uri url,
    required Map<String, String> headers,
    required String body,
  }) async {
    return await _httpClient.post(url, headers: headers, body: body);
  }

  SendFcmResponse _processFcmResponse(http.Response response, bool wasValidation, String? requestBody) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return SendFcmSuccess(responseBody: response.body, wasValidation: wasValidation);
    } else {
      if (kDebugMode) {
        print('FCM API Error Response (${response.statusCode}): ${response.body}');
        print('Failing Request Body: $requestBody');
      }
      return SendFcmFailure(
        message: 'FCM API Error: HTTP status code ${response.statusCode}',
        requestBodyAttempted: requestBody,
        responseBody: response.body,
      );
    }
  }
}
