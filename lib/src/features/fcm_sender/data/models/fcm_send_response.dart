import 'package:flutter/foundation.dart';

@immutable
sealed class SendFcmResponse {}

class SendFcmSuccess extends SendFcmResponse {
  final String responseBody;
  final bool wasValidation;

  SendFcmSuccess({required this.responseBody, required this.wasValidation});
}

class SendFcmFailure extends SendFcmResponse {
  final String message;
  final String? requestBodyAttempted;
  final String? responseBody;
  final dynamic error;
  final StackTrace? stackTrace;

  SendFcmFailure({
    required this.message,
    this.requestBodyAttempted,
    this.responseBody,
    this.error,
    this.stackTrace,
  });
}
