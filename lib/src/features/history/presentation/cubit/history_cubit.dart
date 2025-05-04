import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/history_repository.dart';
import 'history_state.dart';

class HistoryCubit extends Cubit<HistoryState> {
  final HistoryRepository _historyRepository;

  HistoryCubit({required HistoryRepository historyRepository})
      : _historyRepository = historyRepository,
        super(HistoryInitial());

  Future<void> loadHistory() async {
    emit(HistoryLoading());
    try {
      final entries = _historyRepository.getAllHistoryEntries();
      emit(HistoryLoadSuccess(entries));
    } catch (e) {
      if (kDebugMode) {
        print('Error loading history: $e');
      }
      emit(HistoryLoadFailure('Failed to load history: $e'));
    }
  }

  Future<void> clearHistory() async {
    try {
      await _historyRepository.clearHistory();
      emit(const HistoryLoadSuccess([]));
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing history: $e');
      }
      emit(HistoryClearFailure('Failed to clear history: $e'));
    }
  }
}
