// ignore_for_file: prefer_single_quotes

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
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

void main() {
  // Ensure WidgetsFlutterBinding is initialized before using plugins like shared_preferences
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FCM Sender',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const FcmSenderScreen(),
    );
  }
}

class FcmSenderScreen extends StatefulWidget {
  const FcmSenderScreen({super.key});

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
  final _projectIdController = TextEditingController(); // Initialize empty
  final _serviceAccountJsonController = TextEditingController();
  final _targetValueController = TextEditingController();
  final _dataTitleController = TextEditingController(); // These are not saved
  final _dataBodyController = TextEditingController();
  final _dataDeepLinkController = TextEditingController();
  final _additionalDataJsonController = TextEditingController();
  final _analyticsLabelController = TextEditingController();

  // Dropdown/Radio Values - Initialize with defaults, will be overwritten by prefs
  String _selectedTargetType = targetToken;
  String _selectedAndroidPriority = 'DEFAULT';
  String _selectedApnsPriority = 'DEFAULT';

  @override
  void initState() {
    super.initState();
    _loadPreferences(); // Load saved settings when the widget initializes

    // Add listeners to save text field changes automatically
    _serviceAccountJsonController.addListener(_savePreferences);
    _projectIdController.addListener(_savePreferences);
    _targetValueController.addListener(_savePreferences);
    _analyticsLabelController.addListener(_savePreferences);
  }

  @override
  void dispose() {
    // Remove listeners to prevent memory leaks
    _serviceAccountJsonController.removeListener(_savePreferences);
    _projectIdController.removeListener(_savePreferences);
    _targetValueController.removeListener(_savePreferences);
    _analyticsLabelController.removeListener(_savePreferences);

    // Dispose controllers
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
      // Load Setup
      _serviceAccountJsonController.text = prefs.getString(_prefsKeyServiceAccount) ?? '';
      _projectIdController.text = prefs.getString(_prefsKeyProjectId) ?? defaultProjectId; // Use default if null

      // Load Targeting
      _selectedTargetType = prefs.getString(_prefsKeyTargetType) ?? targetToken; // Default to Token
      _targetValueController.text = prefs.getString(_prefsKeyTargetValue) ?? '';
      // Handle the 'All Devices' case where value is fixed
      if (_selectedTargetType == targetAll) {
        _targetValueController.text = defaultAllDevicesTopic;
      }

      // Load Analytics Options
      _analyticsLabelController.text = prefs.getString(_prefsKeyAnalyticsLabel) ?? '';
      _selectedAndroidPriority = prefs.getString(_prefsKeyAndroidPriority) ?? 'DEFAULT';
      _selectedApnsPriority = prefs.getString(_prefsKeyApnsPriority) ?? 'DEFAULT';

      _prefsLoaded = true; // Mark preferences as loaded
    });
    _addToLog("Loaded saved preferences.");
  }

  Future<void> _savePreferences() async {
    // Only save if preferences have been loaded initially to avoid overwriting with defaults
    if (!_prefsLoaded) return;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyServiceAccount, _serviceAccountJsonController.text);
    await prefs.setString(_prefsKeyProjectId, _projectIdController.text);
    await prefs.setString(_prefsKeyTargetType, _selectedTargetType);
    // Only save target value if not 'All Devices' mode, as it's derived then
    if (_selectedTargetType != targetAll) {
      await prefs.setString(_prefsKeyTargetValue, _targetValueController.text);
    } else {
      await prefs.remove(_prefsKeyTargetValue); // Or save the default, but removing is cleaner
    }
    await prefs.setString(_prefsKeyAnalyticsLabel, _analyticsLabelController.text);
    await prefs.setString(_prefsKeyAndroidPriority, _selectedAndroidPriority);
    await prefs.setString(_prefsKeyApnsPriority, _selectedApnsPriority);

    // Optional: Log saving action (can be noisy)
    // print('Preferences saved.');
  }

  // --- Logic Methods (Keep _addToLog, _getAccessToken, _sendFcm, _setStatus as before) ---
  void _addToLog(String message) {
    // Ensure setState is called only if the widget is still mounted
    if (mounted) {
      setState(() {
        final timestamp = DateTime.now().toIso8601String();
        _log += '[$timestamp] $message\n';
      });
    }
  }

  Future<String?> _getAccessToken(String serviceAccountJson) async {
    _addToLog('Attempting to get access token...');
    try {
      if (serviceAccountJson.isEmpty) {
        throw const FormatException('Service Account JSON cannot be empty.');
      }
      final credentialsJson = jsonDecode(serviceAccountJson);
      final credentials = ServiceAccountCredentials.fromJson(credentialsJson);
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

      // Use clientViaServiceAccount to get an authenticated client
      // OR obtain the credentials directly
      final accessCredentials = await obtainAccessCredentialsViaServiceAccount(
        credentials,
        scopes,
        http.Client(), // You can use a shared client if needed
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

  Future<void> _sendFcm({required bool validateOnly}) async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) {
      _setStatus('Error: Please fix validation errors.', isError: true);
      return;
    }

    // --- Make sure preferences are saved before sending (optional but good practice) ---
    // This ensures the *very latest* state is saved if the user hits send immediately
    // after typing without triggering a listener save event (less likely but possible)
    await _savePreferences();

    setState(() {
      _isLoading = true;
      _status = validateOnly ? 'Validating...' : 'Sending...';
      _log = ''; // Clear log on new request
    });

    // --- Values are now read directly from controllers/state variables ---
    // --- which should reflect the latest user input or loaded prefs ---
    final projectId = _projectIdController.text.trim();
    final serviceAccountJson = _serviceAccountJsonController.text.trim();
    final targetValue = _targetValueController.text.trim(); // Already updated by user or prefs
    final additionalDataJson = _additionalDataJsonController.text.trim(); // Not saved/loaded
    final dataTitle = _dataTitleController.text.trim(); // Not saved/loaded
    final dataBody = _dataBodyController.text.trim(); // Not saved/loaded
    final dataDeepLink = _dataDeepLinkController.text.trim(); // Not saved/loaded
    final analyticsLabel = _analyticsLabelController.text.trim(); // Already updated
    final androidPriority = _selectedAndroidPriority == 'DEFAULT' ? null : _selectedAndroidPriority;
    final apnsPriority = _selectedApnsPriority == 'DEFAULT' ? null : _selectedApnsPriority;

    _addToLog('Starting request...');
    _addToLog('Project ID: $projectId');
    _addToLog('Target Type UI: $_selectedTargetType');
    _addToLog('Target Value Input: $targetValue');
    _addToLog('Validate Only: $validateOnly');
    if (analyticsLabel.isNotEmpty) _addToLog('Analytics Label: $analyticsLabel');
    if (androidPriority != null) _addToLog('Android Priority: $androidPriority');
    if (apnsPriority != null) _addToLog('APNS Priority: $apnsPriority');

    // --- Get Access Token ---
    final accessToken = await _getAccessToken(serviceAccountJson);
    if (accessToken == null) {
      // Error logged & status set within _getAccessToken
      if (mounted) setState(() => _isLoading = false); // Ensure loading stops
      return;
    }

    // --- Determine API Target ---
    String? apiTargetType;
    String? apiTargetValue;

    if (_selectedTargetType == targetToken) {
      apiTargetType = 'token';
      apiTargetValue = targetValue;
    } else if (_selectedTargetType == targetTopic || _selectedTargetType == targetAll) {
      apiTargetType = 'topic';
      // Remove potential /topics/ prefix if user added it
      apiTargetValue = targetValue.startsWith('/topics/') ? targetValue.substring('/topics/'.length) : targetValue;
      if (targetValue.startsWith('/topics/')) {
        _addToLog("Note: Corrected topic name to '$apiTargetValue'.");
      }
    }

    if (apiTargetType == null || apiTargetValue == null || apiTargetValue.isEmpty) {
      _setStatus('Error: Invalid target configuration.', isError: true);
      _addToLog('Error: Invalid target type or empty target value.');
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    _addToLog('API Target Type: $apiTargetType');
    _addToLog('API Target Value: $apiTargetValue');

    // --- Construct Data Payload ---
    Map<String, String> finalDataPayload = {}; // Ensure Map<String, String>
    if (additionalDataJson.isNotEmpty) {
      try {
        final parsedJson = jsonDecode(additionalDataJson);
        if (parsedJson is Map) {
          finalDataPayload = parsedJson.map((key, value) => MapEntry(key.toString(), value.toString()));
          _addToLog('Base data from JSON: ${jsonEncode(finalDataPayload)}');
        } else {
          throw const FormatException('Additional Data must be a JSON object (Map).');
        }
      } catch (e) {
        _setStatus('Error: Invalid JSON or structure in Additional Data.', isError: true);
        _addToLog('Error processing Additional Data JSON: $e');
        if (mounted) setState(() => _isLoading = false);
        return;
      }
    }

    // Apply overrides (ensure they are strings)
    if (dataTitle.isNotEmpty) finalDataPayload['title'] = dataTitle;
    if (dataBody.isNotEmpty) finalDataPayload['body'] = dataBody;
    if (dataDeepLink.isNotEmpty) finalDataPayload['deepLink'] = dataDeepLink;
    if (dataTitle.isNotEmpty) _addToLog("Overwriting/adding 'title'");
    if (dataBody.isNotEmpty) _addToLog("Overwriting/adding 'body'");
    if (dataDeepLink.isNotEmpty) _addToLog("Overwriting/adding 'deepLink'");

    if (finalDataPayload.isEmpty && !validateOnly) {
      _setStatus('Error: Resulting data payload is empty.', isError: true);
      _addToLog('Aborted: Cannot send empty data payload.');
      if (mounted) setState(() => _isLoading = false);
      return;
    } else if (finalDataPayload.isEmpty && validateOnly) {
      _addToLog('Warning: Resulting data payload is empty for validation.');
    }

    _addToLog('Final Data Payload Content: ${jsonEncode(finalDataPayload)}');

    // --- Construct FCM Message ---
    final Map<String, dynamic> message = {
      apiTargetType: apiTargetValue,
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
      _addToLog(body);
    }
    _addToLog('--------------------');
    _addToLog('Sending FCM message to $url...');

    // --- Send HTTP Request ---
    try {
      final response = await http.post(url, headers: headers, body: body);
      _addToLog('--- FCM API Call Completed ---');
      _addToLog('Status Code: ${response.statusCode}');
      _addToLog('Response Body:');
      try {
        final responseJson = jsonDecode(response.body);
        const encoder = JsonEncoder.withIndent('  ');
        _addToLog(encoder.convert(responseJson));
      } catch (_) {
        _addToLog(response.body);
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _setStatus(validateOnly ? 'Validation Success!' : 'Success!');
      } else {
        _setStatus('Error sending message. Status: ${response.statusCode}. See log.', isError: true);
        _addToLog('--- Failing Request Body (Sent) ---');
        try {
          const encoder = JsonEncoder.withIndent('  ');
          _addToLog(encoder.convert(requestBody));
        } catch (_) {
          _addToLog(body);
        }
        _addToLog('---------------------------------');
      }
    } catch (e, s) {
      _setStatus('Error: Network request failed or unexpected error.', isError: true);
      _addToLog('An unexpected error occurred during HTTP request: $e');
      _addToLog('Stack trace: $s');
      _addToLog('--- Failing Request Body (Attempted) ---');
      try {
        const encoder = JsonEncoder.withIndent('  ');
        _addToLog(encoder.convert(requestBody));
      } catch (_) {
        _addToLog(body);
      }
      _addToLog('--------------------------------------');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setStatus(String message, {bool isError = false}) {
    if (mounted) {
      setState(() {
        _status = message;
      });
    }
  }

  // --- Build Method (UI) ---
  @override
  Widget build(BuildContext context) {
    // Reorder the sections as they were originally in your code
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple FCM Data Sender'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Status Display ---
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _status.toLowerCase().contains('error') ? Colors.red.shade100 : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _status.toLowerCase().contains('error') ? Colors.red.shade300 : Colors.green.shade300,
                  ),
                ),
                child: Text(
                  'Status: $_status',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _status.toLowerCase().contains('error') ? Colors.red.shade900 : Colors.green.shade900,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // --- Action Buttons ---
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
                        side: const BorderSide(color: Colors.blue),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildSectionHeader('1. Data Payload Content'),
              const Text('Optional overrides (will replace keys in JSON data):'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _dataTitleController, // Not saved
                decoration: const InputDecoration(labelText: "Title Override (Optional - 'title' key)"),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dataBodyController, // Not saved
                decoration: const InputDecoration(labelText: "Body Override (Optional - 'body' key)"),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dataDeepLinkController, // Not saved
                decoration: const InputDecoration(labelText: "Deep Link Override (Optional - 'deepLink' key)"),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text('Base key-value pairs (valid JSON object):'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _additionalDataJsonController, // Not saved
                decoration: const InputDecoration(
                  labelText: 'Additional Data (JSON Object)',
                  hintText: '{\n  "customKey": "customValue",\n  "data_id": "123"\n}',
                  alignLabelWithHint: true,
                ),
                maxLines: 6, minLines: 3,
                validator: (value) {
                  /* Validator remains the same */
                  if (value != null && value.trim().isNotEmpty) {
                    try {
                      final decoded = jsonDecode(value);
                      if (decoded is! Map) return 'Must be a valid JSON object (e.g., {"key": "value"})';
                    } on FormatException {
                      return 'Invalid JSON format';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _buildSectionHeader('2. Analytics Options'),
              TextFormField(
                controller: _analyticsLabelController, // Listener attached in initState
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
                          _savePreferences(); // Save the change
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
                          _savePreferences(); // Save the change
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildSectionHeader('2. Targeting'),
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
                          _targetValueController.clear(); // Clear value when changing type
                        });
                        _savePreferences(); // Save the change
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
                controller: _targetValueController, // Listener attached in initState
                decoration: InputDecoration(
                  labelText: _selectedTargetType == targetToken ? 'Device Token' : 'Topic Name',
                  hintText: _selectedTargetType == targetToken
                      ? 'Enter device FCM token...'
                      : _selectedTargetType == targetAll
                          ? 'Using topic: $defaultAllDevicesTopic'
                          : 'Enter topic name (e.g., news)',
                  enabled: _selectedTargetType != targetAll,
                ),
                readOnly: _selectedTargetType == targetAll,
                validator: (value) {
                  /* Validator remains the same */
                  if (value == null || value.trim().isEmpty) {
                    return 'Target ${_selectedTargetType == targetToken ? 'Token' : 'Topic'} is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _buildSectionHeader('4. Setup'),
              const Text(
                '🚨 Security Warning: Paste your Service Account JSON content below. User Service Json account should be handled very carefully, not to be shared with anyone not in Nexus',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _serviceAccountJsonController, // Listener attached in initState
                decoration: const InputDecoration(
                  labelText: 'Service Account JSON Content',
                  hintText: 'Paste the entire content of your service_account.json file here...',
                  alignLabelWithHint: true,
                ),
                maxLines: 5, minLines: 3,
                validator: (value) {
                  /* Validator remains the same */
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
                controller: _projectIdController, // Listener attached in initState
                decoration: const InputDecoration(labelText: 'Firebase Project ID'),
                validator: (value) {
                  /* Validator remains the same */
                  if (value == null || value.trim().isEmpty) return 'Project ID is required';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _buildSectionHeader('5. Execution Log / API Response'),
              Container(
                height: 250,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.grey.shade100,
                ),
                child: SingleChildScrollView(
                  reverse: true,
                  child: SelectableText(
                    _log.isEmpty ? 'Log output will appear here...' : _log,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
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
