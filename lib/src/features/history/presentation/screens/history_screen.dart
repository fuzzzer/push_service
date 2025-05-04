import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../common/models/fcm_history_entry.dart';
import '../cubit/history_cubit.dart';
import '../cubit/history_state.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  String _formatJson(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return '(empty)';
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(jsonDecode(jsonString));
    } catch (e) {
      return jsonString;
    }
  }

  Future<void> _confirmClearHistory(BuildContext context) async {
    final historyCubit = context.read<HistoryCubit>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History?'),
        content: const Text('Are you sure you want to delete all history entries? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await historyCubit.clearHistory();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('History cleared.'), duration: Duration(seconds: 2)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FCM Send History'),
        actions: [
          BlocBuilder<HistoryCubit, HistoryState>(
            builder: (context, state) {
              final bool canClear = state is HistoryLoadSuccess && state.entries.isNotEmpty;
              return IconButton(
                icon: const Icon(Icons.delete_sweep),
                tooltip: 'Clear All History',
                onPressed: canClear ? () => _confirmClearHistory(context) : null,
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<HistoryCubit, HistoryState>(
        builder: (context, state) {
          if (state is HistoryInitial) {
            context.read<HistoryCubit>().loadHistory();
            return const Center(child: CircularProgressIndicator());
          } else if (state is HistoryLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is HistoryLoadFailure) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error loading history: ${state.message}', textAlign: TextAlign.center),
              ),
            );
          } else if (state is HistoryLoadSuccess) {
            final entries = state.entries;

            if (entries.isEmpty) {
              return const Center(child: Text('No history yet.'));
            }

            return ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _buildHistoryItem(context, entry);
              },
            );
          } else {
            return const Center(child: Text('Unknown history state.'));
          }
        },
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, FcmHistoryEntry entry) {
    final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(entry.timestamp);
    final bool isSuccess = entry.status?.toLowerCase().contains('success') ?? false;
    final bool isFailure = (entry.status?.toLowerCase().contains('fail') ?? false) ||
        (entry.status?.toLowerCase().contains('error') ?? false);

    final Color itemColor = isFailure
        ? Colors.red.shade50
        : isSuccess
            ? Colors.green.shade50
            : Colors.grey.shade100;

    final Color textColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black;
    final Color subtitleColor = Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey.shade700;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: itemColor,
      child: ListTile(
        title: Text(
          '${entry.targetType}: ${entry.targetValue}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: textColor),
        ),
        subtitle: Text(
          'Sent: $formattedDate\nStatus: ${entry.status ?? 'N/A'}',
          style: TextStyle(color: subtitleColor),
        ),
        isThreeLine: true,
        trailing: Icon(Icons.chevron_right, color: textColor),
        onTap: () => _showHistoryDetailDialog(context, entry, formattedDate),
      ),
    );
  }

  void _showHistoryDetailDialog(BuildContext context, FcmHistoryEntry entry, String formattedDate) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('History Detail - $formattedDate'),
        content: SingleChildScrollView(
          child: SelectionArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Target Type: ${entry.targetType}'),
                Text('Target Value: ${entry.targetValue}'),
                if (entry.analyticsLabel != null && entry.analyticsLabel!.isNotEmpty)
                  Text('Analytics Label: ${entry.analyticsLabel}'),
                Text('Status: ${entry.status ?? 'N/A'}'),
                const SizedBox(height: 10),
                const Text('Payload Sent:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatJson(entry.payloadJson),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.white),
                  ),
                ),
                if (entry.responseBody != null && entry.responseBody!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('FCM Response:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatJson(entry.responseBody),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
