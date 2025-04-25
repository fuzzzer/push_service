// ignore_for_file: prefer_single_quotes

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:push_service/fcm_history_entry.dart';
import 'package:push_service/history_screen.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import the package

// --- Configuration ---
const String defaultProjectId = 'super-app-staging-3154d'; // Your Default Project ID
const String targetToken = 'Specific Device (Token)';
const String targetTopic = 'Specific Topic';
const String targetAll = 'All Devices (via Topic)';
const String defaultAllDevicesTopic = 'all';

// --- Preference Keys --- (Define constants for keys)
const String _prefsKeyServiceAccount = 'serviceAccountJson';
const String _prefsKeyProjectId = 'projectId';
const String _prefsKeyTargetType = 'selectedTargetType';
const String _prefsKeyTargetValue = 'targetValue';
const String _prefsKeyAnalyticsLabel = 'analyticsLabel';
const String _prefsKeyAndroidPriority = 'selectedAndroidPriority';
const String _prefsKeyApnsPriority = 'selectedApnsPriority';

const String _prefsKeyTheme = 'themeKey';

const String historyBoxName = 'fcm_send_history';

Future<void> main() async {
  await runner();
}

Future<void> runner() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(FcmHistoryEntryAdapter());
  await Hive.openBox<FcmHistoryEntry>(historyBoxName);

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final themeValue = prefs.getString(_prefsKeyTheme);

  final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(
    themeValue == 'light' ? ThemeMode.light : ThemeMode.dark,
  );

  runApp(MyApp(themeNotifier: themeNotifier));
}

class MyApp extends StatelessWidget {
  final ValueNotifier<ThemeMode> themeNotifier;

  const MyApp({super.key, required this.themeNotifier});

  @override
  Widget build(BuildContext context) {
    final ThemeData lightTheme = ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.blue,
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    final ThemeData darkTheme = ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.blue,
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        return MaterialApp(
          title: 'FCM Sender',
          theme: lightTheme, // Provide light theme
          darkTheme: darkTheme, // Provide dark theme
          themeMode: mode, // Use the current mode from notifier
          home: FcmSenderScreen(themeNotifier: themeNotifier), // Pass notifier down
        );
      },
    );
  }
}

// --- MODIFIED: Accept theme notifier ---
class FcmSenderScreen extends StatefulWidget {
  final ValueNotifier<ThemeMode> themeNotifier; // Accept notifier

  const FcmSenderScreen({super.key, required this.themeNotifier}); // Update constructor

  @override
  State<FcmSenderScreen> createState() => _FcmSenderScreenState();
}

class _FcmSenderScreenState extends State<FcmSenderScreen> {
  // --- State Variables ---
  final _formKey = GlobalKey<FormState>();
  String _status = 'Idle';
  String _log = '';
  bool _isLoading = false;
  bool _prefsLoaded = false; // Flag to prevent saving before loading

  // Controllers
  final _projectIdController = TextEditingController();
  final _serviceAccountJsonController = TextEditingController();
  final _targetValueController = TextEditingController();
  final _dataTitleController = TextEditingController();
  final _dataBodyController = TextEditingController();
  final _dataDeepLinkController = TextEditingController();
  final _additionalDataJsonController = TextEditingController();
  final _analyticsLabelController = TextEditingController();

  // Dropdown/Radio Values
  String _selectedTargetType = targetToken;
  String _selectedAndroidPriority = 'DEFAULT';
  String _selectedApnsPriority = 'DEFAULT';

  @override
  void initState() {
    super.initState();
    _loadPreferences();

    _serviceAccountJsonController.addListener(_savePreferences);
    _projectIdController.addListener(_savePreferences);
    _targetValueController.addListener(_savePreferences);
    _analyticsLabelController.addListener(_savePreferences);
  }

  @override
  void dispose() {
    _serviceAccountJsonController.removeListener(_savePreferences);
    _projectIdController.removeListener(_savePreferences);
    _targetValueController.removeListener(_savePreferences);
    _analyticsLabelController.removeListener(_savePreferences);

    _projectIdController.dispose();
    _serviceAccountJsonController.dispose();
    _targetValueController.dispose();
    _dataTitleController.dispose();
    _dataBodyController.dispose();
    _dataDeepLinkController.dispose();
    _additionalDataJsonController.dispose();
    _analyticsLabelController.dispose();
    super.dispose();
  }

  // --- Preference Logic ---
  Future<void> _loadPreferences() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _serviceAccountJsonController.text = prefs.getString(_prefsKeyServiceAccount) ?? '';
      _projectIdController.text = prefs.getString(_prefsKeyProjectId) ?? defaultProjectId;

      _selectedTargetType = prefs.getString(_prefsKeyTargetType) ?? targetToken;
      // Load saved value only if not 'All Devices' mode
      if (_selectedTargetType != targetAll) {
        _targetValueController.text = prefs.getString(_prefsKeyTargetValue) ?? '';
      } else {
        _targetValueController.text = defaultAllDevicesTopic; // Ensure it's set for display
      }

      _analyticsLabelController.text = prefs.getString(_prefsKeyAnalyticsLabel) ?? '';
      _selectedAndroidPriority = prefs.getString(_prefsKeyAndroidPriority) ?? 'DEFAULT';
      _selectedApnsPriority = prefs.getString(_prefsKeyApnsPriority) ?? 'DEFAULT';

      _prefsLoaded = true;
    });
    _addToLog("Loaded saved preferences.");
  }

  Future<void> _savePreferences() async {
    if (!_prefsLoaded) return;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyServiceAccount, _serviceAccountJsonController.text);
    await prefs.setString(_prefsKeyProjectId, _projectIdController.text);
    await prefs.setString(_prefsKeyTargetType, _selectedTargetType);
    // Only save target value if not 'All Devices' mode
    if (_selectedTargetType != targetAll) {
      await prefs.setString(_prefsKeyTargetValue, _targetValueController.text);
    } else {
      await prefs.remove(_prefsKeyTargetValue); // Clean up prefs if switching to All
    }
    await prefs.setString(_prefsKeyAnalyticsLabel, _analyticsLabelController.text);
    await prefs.setString(_prefsKeyAndroidPriority, _selectedAndroidPriority);
    await prefs.setString(_prefsKeyApnsPriority, _selectedApnsPriority);
  }

  // --- Logging ---
  void _addToLog(String message) {
    if (mounted) {
      setState(() {
        final timestamp = DateTime.now().toIso8601String();
        _log += '[$timestamp] $message\n';
      });
    }
  }

  // --- Status Update ---
  void _setStatus(String message, {bool isError = false}) {
    if (mounted) {
      setState(() {
        _status = message;
      });
    }
  }

  // --- Helper to save history ---
  Future<void> _saveToHistory({
    required String targetType, // e.g., 'token', 'topic', or the UI description like targetAll
    required String targetValue, // The actual token, topic name, or default topic
    required Map<String, dynamic> payload, // The actual data map sent/attempted
    String? analyticsLabel,
    required String status, // e.g., 'Success', 'Validation Success', 'Error: ...'
    String? responseBody, // The raw response string from FCM or client error
  }) async {
    try {
      await Hive.openBox<FcmHistoryEntry>(historyBoxName); // Open the history box
      final historyBox = Hive.box<FcmHistoryEntry>(historyBoxName);
      final entry = FcmHistoryEntry(
        timestamp: DateTime.now(),
        targetType: targetType, // Store the logical type
        targetValue: targetValue,
        payloadJson: jsonEncode(payload), // Store payload as JSON string
        analyticsLabel: analyticsLabel,
        status: status,
        responseBody: responseBody,
      );
      await historyBox.add(entry); // Add to the box
      _addToLog('Saved send attempt to history.');
    } catch (e) {
      _addToLog('Error saving to history: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save to history: $e'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  // --- Access Token Logic ---
  Future<String?> _getAccessToken(String serviceAccountJson) async {
    _addToLog('Attempting to get access token...');
    try {
      if (serviceAccountJson.isEmpty) {
        throw const FormatException('Service Account JSON cannot be empty.');
      }
      final credentialsJson = jsonDecode(serviceAccountJson);
      final credentials = ServiceAccountCredentials.fromJson(credentialsJson);
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

      final accessCredentials = await obtainAccessCredentialsViaServiceAccount(
        credentials,
        scopes,
        http.Client(),
      );

      _addToLog('Access token obtained successfully.');
      return accessCredentials.accessToken.data;
    } on FormatException catch (e) {
      _addToLog('Error parsing Service Account JSON: $e');
      _setStatus('Error: Invalid Service Account JSON format.', isError: true);
      return null;
    } catch (e) {
      _addToLog('Error getting access token: $e');
      _setStatus('Error: Failed to get access token. Check JSON and network.', isError: true);
      return null;
    }
  }

  // --- Send FCM Logic ---
  Future<void> _sendFcm({required bool validateOnly}) async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) {
      _setStatus('Error: Please fix validation errors.', isError: true);
      return;
    }

    await _savePreferences();

    setState(() {
      _isLoading = true;
      _status = validateOnly ? 'Validating...' : 'Sending...';
      _log = ''; // Clear log on new request
    });

    final projectId = _projectIdController.text.trim();
    final serviceAccountJson = _serviceAccountJsonController.text.trim();
    final targetValueInput = _targetValueController.text.trim(); // User input or default topic
    final additionalDataJson = _additionalDataJsonController.text.trim();
    final dataTitle = _dataTitleController.text.trim();
    final dataBody = _dataBodyController.text.trim();
    final dataDeepLink = _dataDeepLinkController.text.trim();
    final analyticsLabel = _analyticsLabelController.text.trim();
    final androidPriority = _selectedAndroidPriority == 'DEFAULT' ? null : _selectedAndroidPriority;
    final apnsPriority = _selectedApnsPriority == 'DEFAULT' ? null : _selectedApnsPriority;

    // --- Declare variables needed for history saving ---
    String? apiTargetTypeForHistory; // Can be 'token', 'topic'
    String? apiTargetValueForHistory; // Can be token or topic name
    Map<String, String> finalDataPayload = {}; // Start empty
    String finalStatus = 'Send Attempted'; // Default status before API call
    String? responseBodyContent;

    _addToLog('Starting request...');
    _addToLog('Project ID: $projectId');
    _addToLog('Target Type UI: $_selectedTargetType');
    _addToLog('Target Value Input: $targetValueInput');
    _addToLog('Validate Only: $validateOnly');
    if (analyticsLabel.isNotEmpty) _addToLog('Analytics Label: $analyticsLabel');
    if (androidPriority != null) _addToLog('Android Priority: $androidPriority');
    if (apnsPriority != null) _addToLog('APNS Priority: $apnsPriority');

    // --- Get Access Token ---
    final accessToken = await _getAccessToken(serviceAccountJson);
    if (accessToken == null) {
      // Error already logged & status set in _getAccessToken
      if (mounted) setState(() => _isLoading = false);
      // *** Save history entry for auth failure ***
      await _saveToHistory(
        targetType: _selectedTargetType, // Use UI selection as context
        targetValue: targetValueInput,
        payload: {}, // No payload constructed
        analyticsLabel: analyticsLabel.isNotEmpty ? analyticsLabel : null,
        status: _status,
      );
      return;
    }

    // --- Determine API Target ---
    if (_selectedTargetType == targetToken) {
      apiTargetTypeForHistory = 'token';
      apiTargetValueForHistory = targetValueInput;
    } else if (_selectedTargetType == targetTopic || _selectedTargetType == targetAll) {
      apiTargetTypeForHistory = 'topic';
      // Use the corrected topic name (input or default)
      apiTargetValueForHistory =
          targetValueInput.startsWith('/topics/') ? targetValueInput.substring('/topics/'.length) : targetValueInput;
      if (targetValueInput.startsWith('/topics/')) {
        _addToLog("Note: Corrected topic name to '$apiTargetValueForHistory'.");
      }
    }

    // This validation should ideally not fail if form validation passed, but check anyway
    if (apiTargetTypeForHistory == null || apiTargetValueForHistory == null || apiTargetValueForHistory.isEmpty) {
      finalStatus = 'Error: Invalid target configuration.';
      _setStatus(finalStatus, isError: true);
      _addToLog('Error: Invalid API target type or empty target value after processing.');
      if (mounted) setState(() => _isLoading = false);
      // *** Save history entry for target config failure ***
      await _saveToHistory(
        targetType: _selectedTargetType, // UI context
        targetValue: targetValueInput, // Raw input
        payload: {},
        analyticsLabel: analyticsLabel.isNotEmpty ? analyticsLabel : null,
        status: finalStatus,
        responseBody: 'Internal error determining API target.',
      );
      return;
    }
    _addToLog('API Target Type: $apiTargetTypeForHistory');
    _addToLog('API Target Value: $apiTargetValueForHistory');

    // --- Construct Data Payload ---
    if (additionalDataJson.isNotEmpty) {
      try {
        final parsedJson = jsonDecode(additionalDataJson);
        if (parsedJson is Map) {
          // Convert all keys and values to strings
          finalDataPayload = parsedJson.map((key, value) => MapEntry(key.toString(), value.toString()));
          _addToLog('Base data from JSON: ${jsonEncode(finalDataPayload)}');
        } else {
          throw const FormatException('Additional Data must be a JSON object (Map).');
        }
      } catch (e) {
        finalStatus = 'Error: Invalid JSON or structure in Additional Data.';
        _setStatus(finalStatus, isError: true);
        _addToLog('Error processing Additional Data JSON: $e');
        if (mounted) setState(() => _isLoading = false);
        // *** Save history entry for payload JSON failure ***
        await _saveToHistory(
          targetType: apiTargetTypeForHistory, // We know it's set now
          targetValue: apiTargetValueForHistory,
          payload: {}, // Payload construction failed
          analyticsLabel: analyticsLabel.isNotEmpty ? analyticsLabel : null,
          status: finalStatus,
          responseBody: 'Error parsing input JSON: $e',
        );
        return;
      }
    }

    // Apply overrides
    if (dataTitle.isNotEmpty) {
      finalDataPayload['title'] = dataTitle;
      _addToLog("Overwriting/adding 'title'");
    }
    if (dataBody.isNotEmpty) {
      finalDataPayload['body'] = dataBody;
      _addToLog("Overwriting/adding 'body'");
    }
    if (dataDeepLink.isNotEmpty) {
      finalDataPayload['deepLink'] = dataDeepLink;
      _addToLog("Overwriting/adding 'deepLink'");
    }

    // Check if payload is empty *after* overrides
    if (finalDataPayload.isEmpty && !validateOnly) {
      finalStatus = 'Error: Resulting data payload is empty.';
      _setStatus(finalStatus, isError: true);
      _addToLog('Aborted: Cannot send empty data payload.');
      if (mounted) setState(() => _isLoading = false);
      // *** Save history entry for empty payload failure ***
      await _saveToHistory(
        targetType: apiTargetTypeForHistory,
        targetValue: apiTargetValueForHistory,
        payload: finalDataPayload, // It's empty here
        analyticsLabel: analyticsLabel.isNotEmpty ? analyticsLabel : null,
        status: finalStatus,
      );
      return;
    } else if (finalDataPayload.isEmpty && validateOnly) {
      _addToLog('Warning: Resulting data payload is empty for validation.');
      // Allow validation of empty payload
    }

    _addToLog('Final Data Payload Content: ${jsonEncode(finalDataPayload)}');

    final Map<String, dynamic> message = {
      apiTargetTypeForHistory: apiTargetValueForHistory,
      'data': finalDataPayload,
    };

    final Map<String, dynamic> androidConfig = {};
    if (androidPriority != null) androidConfig['priority'] = androidPriority;
    if (androidConfig.isNotEmpty) message['android'] = androidConfig;

    final Map<String, dynamic> apnsConfig = {};
    final Map<String, String> apnsHeaders = {};
    if (apnsPriority != null) apnsHeaders['apns-priority'] = apnsPriority;
    if (apnsHeaders.isNotEmpty) apnsConfig['headers'] = apnsHeaders;
    if (apnsConfig.isNotEmpty) message['apns'] = apnsConfig;

    final Map<String, dynamic> fcmOptions = {};
    if (analyticsLabel.isNotEmpty) fcmOptions['analytics_label'] = analyticsLabel;
    if (fcmOptions.isNotEmpty) message['fcm_options'] = fcmOptions;

    final Map<String, dynamic> requestBody = {'message': message};
    if (validateOnly) requestBody['validate_only'] = true;

    final url = Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send');
    final headers = {'Authorization': 'Bearer $accessToken', 'Content-Type': 'application/json'};
    final body = jsonEncode(requestBody);

    _addToLog('--- Request Body ---');
    try {
      const encoder = JsonEncoder.withIndent('  ');
      _addToLog(encoder.convert(requestBody));
    } catch (_) {
      _addToLog(body); // Fallback if encoding fails
    }
    _addToLog('--------------------');
    _addToLog('Sending FCM message to $url...');

    // --- Send HTTP Request & Update Status ---
    try {
      final response = await http.post(url, headers: headers, body: body);
      responseBodyContent = response.body; // Capture response body

      _addToLog('--- FCM API Call Completed ---');
      _addToLog('Status Code: ${response.statusCode}');
      _addToLog('Response Body:');
      try {
        final responseJson = jsonDecode(response.body);
        const encoder = JsonEncoder.withIndent('  ');
        _addToLog(encoder.convert(responseJson));
      } catch (_) {
        _addToLog(response.body); // Log raw body if JSON parsing fails
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        finalStatus = validateOnly ? 'Validation Success!' : 'Success!';
        _setStatus(finalStatus);
      } else {
        finalStatus = 'Error sending message. Status: ${response.statusCode}';
        _setStatus(finalStatus, isError: true);
        _addToLog('--- Failing Request Body (Sent) ---');
        _addToLog(body); // Log the body that caused the failure
        _addToLog('---------------------------------');
      }
    } catch (e, s) {
      finalStatus = 'Error: Network request failed or unexpected error.';
      responseBodyContent = "Client-side error during HTTP POST: $e\nStack: $s"; // Capture client error details
      _setStatus(finalStatus, isError: true);
      _addToLog('An unexpected error occurred during HTTP request: $e');
      _addToLog('Stack trace: $s');
      _addToLog('--- Failing Request Body (Attempted) ---');
      _addToLog(body); // Log the body that was attempted
      _addToLog('--------------------------------------');
    } finally {
      // *** Save history entry AFTER the attempt (success or failure) ***
      await _saveToHistory(
        targetType: apiTargetTypeForHistory, // Use determined API type
        targetValue: apiTargetValueForHistory, // Use determined API value
        payload: finalDataPayload, // The actual payload sent/attempted
        analyticsLabel: analyticsLabel.isNotEmpty ? analyticsLabel : null,
        status: finalStatus, // Status determined above
        responseBody: responseBodyContent, // Captured response or error
      );

      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- Build Method (UI) ---
  @override
  Widget build(BuildContext context) {
    // Use Theme.of(context) to adapt colors if needed (optional, basic themes handle most)
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color errorColor = isDarkMode ? Colors.red.shade300 : Colors.red.shade900;
    final Color successColor = isDarkMode ? Colors.green.shade300 : Colors.green.shade900;
    final Color errorBgColor = isDarkMode ? Colors.red.shade800.withOpacity(0.3) : Colors.red.shade100;
    final Color successBgColor = isDarkMode ? Colors.green.shade800.withOpacity(0.3) : Colors.green.shade100;
    final Color errorBorderColor = isDarkMode ? Colors.red.shade500 : Colors.red.shade300;
    final Color successBorderColor = isDarkMode ? Colors.green.shade500 : Colors.green.shade300;
    final Color disabledFillColor = Theme.of(context).disabledColor.withOpacity(0.1);
    final Color logBgColor = Theme.of(context).colorScheme.surfaceVariant;
    final Color logTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final Color logBorderColor = Theme.of(context).dividerColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple FCM Data Sender'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View Send History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HistoryScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _status.toLowerCase().contains('error') ? errorBgColor : successBgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _status.toLowerCase().contains('error') ? errorBorderColor : successBorderColor,
                  ),
                ),
                child: Text(
                  'Status: $_status',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _status.toLowerCase().contains('error') ? errorColor : successColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send),
                      label: const Text('Send Notification'),
                      onPressed: _isLoading ? null : () => _sendFcm(validateOnly: false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check_circle_outline),
                      label: const Text('Validate Only'),
                      onPressed: _isLoading ? null : () => _sendFcm(validateOnly: true),
                      style: ElevatedButton.styleFrom(
                        side: BorderSide(color: Theme.of(context).colorScheme.primary),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // --- Section 1: Data Payload ---
              _buildSectionHeader('1. Data Payload Content'),
              const Text('Optional overrides (will replace keys in JSON data):'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _dataTitleController,
                decoration: const InputDecoration(labelText: "Title Override (Optional - 'title' key)"),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dataBodyController,
                decoration: const InputDecoration(labelText: "Body Override (Optional - 'body' key)"),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dataDeepLinkController,
                decoration: const InputDecoration(labelText: "Deep Link Override (Optional - 'deepLink' key)"),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text('Base key-value pairs (valid JSON object):'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _additionalDataJsonController,
                decoration: const InputDecoration(
                  labelText: 'Additional Data (JSON Object)',
                  hintText: '{\n  "customKey": "customValue",\n  "data_id": "123"\n}',
                  alignLabelWithHint: true,
                ),
                maxLines: 6,
                minLines: 3,
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    try {
                      final decoded = jsonDecode(value);
                      if (decoded is! Map) return 'Must be a valid JSON object (e.g., {"key": "value"})';
                    } on FormatException {
                      return 'Invalid JSON format';
                    }
                  }
                  // Allow empty or null input here, handle empty payload logic in _sendFcm
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // --- Section 2: Analytics & Priority ---
              _buildSectionHeader('2. Analytics & Priority'),
              TextFormField(
                controller: _analyticsLabelController,
                decoration: const InputDecoration(labelText: 'Analytics Label (Optional)'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedAndroidPriority,
                      decoration: const InputDecoration(labelText: 'Android Priority'),
                      items: ['DEFAULT', 'NORMAL', 'HIGH']
                          .map((label) => DropdownMenuItem(value: label, child: Text(label)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null && value != _selectedAndroidPriority) {
                          setState(() => _selectedAndroidPriority = value);
                          _savePreferences();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedApnsPriority,
                      decoration: const InputDecoration(labelText: 'APNS Priority'),
                      items: ['DEFAULT', '5', '10']
                          .map(
                            (label) => DropdownMenuItem(
                              value: label,
                              child: Text(
                                label == '5'
                                    ? '5 (Normal)'
                                    : label == '10'
                                        ? '10 (High)'
                                        : label,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null && value != _selectedApnsPriority) {
                          setState(() => _selectedApnsPriority = value);
                          _savePreferences();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // --- Section 3: Targeting ---
              _buildSectionHeader('3. Targeting'),
              Column(
                children: [
                  RadioListTile<String>(
                    title: const Text(targetToken),
                    value: targetToken,
                    groupValue: _selectedTargetType,
                    onChanged: (String? value) {
                      if (value != null && value != _selectedTargetType) {
                        setState(() {
                          _selectedTargetType = value;
                          _targetValueController.clear(); // Clear specific value when switching
                        });
                        _savePreferences();
                      }
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<String>(
                    title: const Text(targetTopic),
                    value: targetTopic,
                    groupValue: _selectedTargetType,
                    onChanged: (String? value) {
                      if (value != null && value != _selectedTargetType) {
                        setState(() {
                          _selectedTargetType = value;
                          _targetValueController.clear();
                        });
                        _savePreferences();
                      }
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<String>(
                    title: const Text(targetAll),
                    value: targetAll,
                    groupValue: _selectedTargetType,
                    onChanged: (String? value) {
                      if (value != null && value != _selectedTargetType) {
                        setState(() {
                          _selectedTargetType = value;
                          _targetValueController.text = defaultAllDevicesTopic; // Auto-set value
                        });
                        _savePreferences();
                      }
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _targetValueController,
                decoration: InputDecoration(
                  labelText: _selectedTargetType == targetToken ? 'Device Token' : 'Topic Name',
                  hintText: _selectedTargetType == targetToken
                      ? 'Enter device FCM token...'
                      : _selectedTargetType == targetAll
                          ? 'Using topic: $defaultAllDevicesTopic'
                          : 'Enter topic name (e.g., news)',
                  enabled: _selectedTargetType != targetAll, // Disable editing for 'All'
                  filled: _selectedTargetType == targetAll, // Visually indicate read-only
                  fillColor: _selectedTargetType == targetAll ? disabledFillColor : null, // Theme-aware fill
                ),
                readOnly: _selectedTargetType == targetAll, // Make it truly read-only
                validator: (value) {
                  // Only validate if NOT in 'All Devices' mode
                  if (_selectedTargetType != targetAll && (value == null || value.trim().isEmpty)) {
                    return 'Target ${_selectedTargetType == targetToken ? 'Token' : 'Topic'} is required';
                  }
                  return null; // No error if 'All Devices' or if value is present otherwise
                },
              ),
              const SizedBox(height: 20),

              // --- Section 4: Setup ---
              _buildSectionHeader('4. Setup'),
              const Text(
                '🚨 Security Warning: Paste your Service Account JSON content below. Handle this securely do not share with anyone, that should not be able to send push.',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _serviceAccountJsonController,
                decoration: const InputDecoration(
                  labelText: 'Service Account JSON Content',
                  hintText: 'Paste the entire content of your service_account.json file here...',
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                minLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Service Account JSON is required';
                  try {
                    final decoded = jsonDecode(value);
                    if (decoded is! Map) return 'Must be a valid JSON object';
                    if (!decoded.containsKey('project_id') ||
                        !decoded.containsKey('private_key') ||
                        !decoded.containsKey('client_email')) {
                      return 'JSON seems incomplete (missing common keys)';
                    }
                  } on FormatException {
                    return 'Invalid JSON format';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _projectIdController,
                decoration: const InputDecoration(labelText: 'Firebase Project ID'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Project ID is required';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // --- Section 5: Log ---
              _buildSectionHeader('5. Execution Log / API Response'),
              Container(
                height: 250,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: logBorderColor),
                  borderRadius: BorderRadius.circular(4),
                  color: logBgColor,
                ),
                child: SingleChildScrollView(
                  reverse: true, // Keep latest logs visible
                  child: SelectableText(
                    _log.isEmpty ? 'Log output will appear here...' : _log,
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: logTextColor), // Use theme color
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Divider(height: 30),
              _buildSectionHeader('App Theme'),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.wb_sunny_outlined),
                    label: const Text('Light'),
                    onPressed: () async {
                      widget.themeNotifier.value = ThemeMode.light;
                      final SharedPreferences prefs = await SharedPreferences.getInstance();
                      await prefs.setString(_prefsKeyTheme, 'light');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !isDarkMode ? Theme.of(context).colorScheme.primary : null,
                      foregroundColor: !isDarkMode ? Theme.of(context).colorScheme.onPrimary : null,
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.brightness_2_outlined),
                    label: const Text('Dark'),
                    onPressed: () async {
                      widget.themeNotifier.value = ThemeMode.dark;
                      final SharedPreferences prefs = await SharedPreferences.getInstance();
                      await prefs.setString(_prefsKeyTheme, 'dark');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDarkMode ? Theme.of(context).colorScheme.primary : null,
                      foregroundColor: isDarkMode ? Theme.of(context).colorScheme.onPrimary : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Helper to build section headers
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
