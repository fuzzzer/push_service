import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'fcm_history_entry_old.dart';
import 'main.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Box<FcmHistoryEntryOld> _historyBox;

  @override
  void initState() {
    super.initState();
    _historyBox = Hive.box<FcmHistoryEntryOld>(historyBoxName);
  }

  String _formatJson(String jsonString) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(jsonDecode(jsonString));
    } catch (e) {
      return jsonString;
    }
  }

  Future<void> _clearHistory() async {
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
      await _historyBox.clear();

      if (mounted) {
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
          ValueListenableBuilder(
            valueListenable: _historyBox.listenable(),
            builder: (context, Box<FcmHistoryEntryOld> box, _) {
              return IconButton(
                icon: const Icon(Icons.delete_sweep),
                tooltip: 'Clear All History',
                onPressed: box.isEmpty ? null : _clearHistory,
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: _historyBox.listenable(),
        builder: (context, Box<FcmHistoryEntryOld> box, _) {
          if (box.isEmpty) {
            return const Center(child: Text('No history yet.'));
          }

          final entries = box.values.toList().reversed.toList();

          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(entry.timestamp);
              final statusColor = entry.status?.toLowerCase().contains('fail') ?? false
                  ? Colors.red.shade100
                  : entry.status?.toLowerCase().contains('success') ?? false
                      ? Colors.green.shade100
                      : Colors.grey.shade200;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: statusColor,
                child: ListTile(
                  title:
                      Text('${entry.targetType}: ${entry.targetValue}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('Sent: $formattedDate\nStatus: ${entry.status ?? 'N/A'}'),
                  textColor: Colors.black,
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
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
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.grey.shade300),
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
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.white),
                                    ),
                                    child: Text(
                                      _formatJson(entry.responseBody!),
                                      style:
                                          const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.white),
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
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
