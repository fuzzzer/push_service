import 'package:flutter/foundation.dart';

import '../../../common/models/fcm_history_entry.dart';

@immutable
abstract class HistoryState {
  const HistoryState();
}

class HistoryInitial extends HistoryState {}

class HistoryLoading extends HistoryState {}

class HistoryLoadSuccess extends HistoryState {
  final List<FcmHistoryEntry> entries;

  const HistoryLoadSuccess(this.entries);

  @override
  bool operator ==(covariant HistoryLoadSuccess other) {
    if (identical(this, other)) return true;

    return listEquals(other.entries, entries);
  }

  @override
  int get hashCode => entries.hashCode;
}

class HistoryLoadFailure extends HistoryState {
  final String message;

  const HistoryLoadFailure(this.message);

  @override
  bool operator ==(covariant HistoryLoadFailure other) {
    if (identical(this, other)) return true;

    return other.message == message;
  }

  @override
  int get hashCode => message.hashCode;
}

class HistoryClearing extends HistoryState {}

class HistoryClearSuccess extends HistoryState {}

class HistoryClearFailure extends HistoryState {
  final String message;
  const HistoryClearFailure(this.message);
  @override
  @override
  bool operator ==(covariant HistoryClearFailure other) {
    if (identical(this, other)) return true;

    return other.message == message;
  }

  @override
  int get hashCode => message.hashCode;
}
