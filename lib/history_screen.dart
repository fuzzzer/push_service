// lib/history_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart'; // For date formatting (add dependency if needed)
import 'fcm_history_entry.dart'; // Import model
import 'main.dart'; // Import main to access historyBoxName

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Box<FcmHistoryEntry> _historyBox;

  @override
  void initState() {
    super.initState();
    _historyBox = Hive.box<FcmHistoryEntry>(historyBoxName);
  }

  // Function to format JSON nicely
  String _formatJson(String jsonString) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(jsonDecode(jsonString));
    } catch (e) {
      return jsonString; // Return original if parsing fails
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
      // No need for setState here as ValueListenableBuilder handles updates
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
          // Use ValueListenableBuilder to enable/disable clear button
          ValueListenableBuilder(
            valueListenable: _historyBox.listenable(),
            builder: (context, Box<FcmHistoryEntry> box, _) {
              return IconButton(
                icon: const Icon(Icons.delete_sweep),
                tooltip: 'Clear All History',
                onPressed: box.isEmpty ? null : _clearHistory, // Disable if empty
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder(
        // Listen to the box for changes (add, delete, clear)
        valueListenable: _historyBox.listenable(),
        builder: (context, Box<FcmHistoryEntry> box, _) {
          if (box.isEmpty) {
            return const Center(child: Text('No history yet.'));
          }

          // Display newest first
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
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Show details in a dialog
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('History Detail - $formattedDate'),
                        content: SingleChildScrollView(
                          child: SelectionArea(
                            // Allow copying text
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
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Text(
                                    _formatJson(entry.payloadJson),
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                  ),
                                ),
                                if (entry.responseBody != null && entry.responseBody!.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  const Text('FCM Response:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Text(
                                      _formatJson(entry.responseBody!), // Format response too
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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
