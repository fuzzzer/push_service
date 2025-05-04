import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../config/constants.dart';
import '../../../common/models/fcm_history_entry.dart';

class HistoryRepository {
  late Box<FcmHistoryEntry> _historyBox;

  HistoryRepository() {
    _historyBox = Hive.box<FcmHistoryEntry>(HISTORY_BOX_NAME);
  }

  Box<FcmHistoryEntry> get historyBox => _historyBox;

  Future<void> saveHistoryEntry(FcmHistoryEntry entry) async {
    try {
      await _historyBox.add(entry);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving to history: $e');
      }

      rethrow;
    }
  }

  List<FcmHistoryEntry> getAllHistoryEntries() {
    try {
      return _historyBox.values.toList().reversed.toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting history entries: $e');
      }
      return [];
    }
  }

  Future<void> clearHistory() async {
    try {
      await _historyBox.clear();
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing history: $e');
      }
      rethrow;
    }
  }
}
