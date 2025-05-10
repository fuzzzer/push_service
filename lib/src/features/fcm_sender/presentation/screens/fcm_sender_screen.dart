// ignore_for_file: deprecated_member_use

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../config/constants.dart';
import '../../../history/presentation/screens/history_screen.dart';
import '../../../preferences/data/services/preferences_service.dart';
import '../cubit/fcm_sender_cubit.dart';
import '../cubit/fcm_sender_state.dart';
import '../widgets/section_header.dart';

class FcmSenderScreen extends StatefulWidget {
  final ValueNotifier<ThemeMode> themeNotifier;

  const FcmSenderScreen({super.key, required this.themeNotifier});

  @override
  State<FcmSenderScreen> createState() => _FcmSenderScreenState();
}

class _FcmSenderScreenState extends State<FcmSenderScreen> {
  final _formKey = GlobalKey<FormState>();

  final _projectIdController = TextEditingController();
  final _serviceAccountJsonController = TextEditingController();
  final _targetValueController = TextEditingController();
  final _dataTitleController = TextEditingController();
  final _dataBodyController = TextEditingController();
  final _dataDeepLinkController = TextEditingController();
  final _additionalDataJsonController = TextEditingController();
  final _analyticsLabelController = TextEditingController();

  @override
  void initState() {
    super.initState();

    context.read<FcmSenderCubit>().loadPreferences();

    _serviceAccountJsonController.addListener(() {
      context.read<FcmSenderCubit>().updateServiceAccountJson(_serviceAccountJsonController.text);
    });
    _projectIdController.addListener(() {
      context.read<FcmSenderCubit>().updateProjectId(_projectIdController.text);
    });
    _targetValueController.addListener(() {
      context.read<FcmSenderCubit>().updateTargetValue(_targetValueController.text);
    });
    _analyticsLabelController.addListener(() {
      context.read<FcmSenderCubit>().updateAnalyticsLabel(_analyticsLabelController.text);
    });

    _dataTitleController.addListener(() => context.read<FcmSenderCubit>().updateDataTitle(_dataTitleController.text));
    _dataBodyController.addListener(() => context.read<FcmSenderCubit>().updateDataBody(_dataBodyController.text));
    _dataDeepLinkController
        .addListener(() => context.read<FcmSenderCubit>().updateDataDeepLink(_dataDeepLinkController.text));
    _additionalDataJsonController
        .addListener(() => context.read<FcmSenderCubit>().updateAdditionalDataJson(_additionalDataJsonController.text));
  }

  @override
  void dispose() {
    _serviceAccountJsonController.removeListener(() {});
    _projectIdController.removeListener(() {});
    _targetValueController.removeListener(() {});
    _analyticsLabelController.removeListener(() {});
    _dataTitleController.removeListener(() {});
    _dataBodyController.removeListener(() {});
    _dataDeepLinkController.removeListener(() {});
    _additionalDataJsonController.removeListener(() {});

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

  void _handleSend(BuildContext context, {required bool validateOnly}) {
    if (_formKey.currentState!.validate()) {
      context.read<FcmSenderCubit>().sendFcm(validateOnly: validateOnly);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix validation errors before sending.'), backgroundColor: Colors.orange),
      );
    }
  }

  void _updateControllersFromState(FcmSenderState state) {
    if (_serviceAccountJsonController.text != state.serviceAccountJson) {
      _serviceAccountJsonController.text = state.serviceAccountJson;
    }
    if (_projectIdController.text != state.projectId) {
      _projectIdController.text = state.projectId;
    }

    if (state.targetType != TargetType.allChosenDevices && _targetValueController.text != state.targetValue) {
      _targetValueController.text = state.targetValue;
    } else if (state.targetType == TargetType.allChosenDevices) {
      _targetValueController.text = switch (state.targetDevice) {
        TargetDevice.all => DEFAULT_ALL_DEVICES_TOPIC,
        TargetDevice.android => DEFAULT_ANDROID_DEVICES_TOPIC,
        TargetDevice.ios => DEFAULT_IOS_DEVICES_TOPIC,
      };
    }

    if (_analyticsLabelController.text != state.analyticsLabel) {
      _analyticsLabelController.text = state.analyticsLabel;
    }

    if (_dataTitleController.text != state.dataTitle) _dataTitleController.text = state.dataTitle;
    if (_dataBodyController.text != state.dataBody) _dataBodyController.text = state.dataBody;
    if (_dataDeepLinkController.text != state.dataDeepLink) _dataDeepLinkController.text = state.dataDeepLink;
    if (_additionalDataJsonController.text != state.additionalDataJson) {
      _additionalDataJsonController.text = state.additionalDataJson;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color errorColor = Colors.red.shade700;
    final Color successColor = Colors.green.shade700;
    final Color validationSuccessColor = Colors.blue.shade700;
    final Color logBgColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    final Color logTextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final Color logBorderColor = Theme.of(context).dividerColor;
    final Color disabledFillColor = Theme.of(context).disabledColor.withOpacity(0.1);

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
      body: BlocListener<FcmSenderCubit, FcmSenderState>(
        listener: (context, state) {
          _updateControllersFromState(state);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: BlocBuilder<FcmSenderCubit, FcmSenderState>(
            builder: (context, state) {
              final bool isLoading = state.sendStatus == FcmSendStatus.loading;

              Color statusBgColor;
              Color statusFgColor;
              switch (state.sendStatus) {
                case FcmSendStatus.loading:
                case FcmSendStatus.initial:
                  statusBgColor = Theme.of(context).colorScheme.surfaceContainerHighest;
                  statusFgColor = Theme.of(context).colorScheme.onSurfaceVariant;
                case FcmSendStatus.success:
                  statusBgColor = Colors.green.shade100;
                  statusFgColor = successColor;
                case FcmSendStatus.validationSuccess:
                  statusBgColor = Colors.blue.shade100;
                  statusFgColor = validationSuccessColor;
                case FcmSendStatus.failure:
                  statusBgColor = Colors.red.shade100;
                  statusFgColor = errorColor;
              }

              return Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusFgColor.withOpacity(0.5)),
                      ),
                      child: Text(
                        'Status: ${state.statusMessage}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: statusFgColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.send),
                            label: const Text('Send Notification'),
                            onPressed: isLoading ? null : () => _handleSend(context, validateOnly: false),
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
                            icon: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: const Text('Validate Only'),
                            onPressed: isLoading ? null : () => _handleSend(context, validateOnly: true),
                            style: ElevatedButton.styleFrom(
                              side: BorderSide(color: Theme.of(context).colorScheme.primary),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const SectionHeader('1. Data Payload Content'),
                    const Text('Optional overrides (will replace keys in JSON data):'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _dataTitleController,
                      decoration: const InputDecoration(labelText: "Title Override (Optional - 'title' key)"),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _dataBodyController,
                      decoration: const InputDecoration(labelText: "Body Override (Optional - 'body' key)"),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _dataDeepLinkController,
                      decoration: const InputDecoration(labelText: "Deep Link Override (Optional - 'deepLink' key)"),
                      enabled: !isLoading,
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
                      enabled: !isLoading,
                      validator: (value) {
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
                    const SectionHeader('2. Analytics & Priority'),
                    TextFormField(
                      controller: _analyticsLabelController,
                      decoration: const InputDecoration(labelText: 'Analytics Label (Optional)'),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: state.androidPriority,
                            decoration: const InputDecoration(labelText: 'Android Priority'),
                            items: ['DEFAULT', 'NORMAL', 'HIGH']
                                .map((label) => DropdownMenuItem(value: label, child: Text(label)))
                                .toList(),
                            onChanged: isLoading
                                ? null
                                : (value) {
                                    if (value != null) {
                                      context.read<FcmSenderCubit>().updateAndroidPriority(value);
                                    }
                                  },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: state.apnsPriority,
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
                            onChanged: isLoading
                                ? null
                                : (value) {
                                    if (value != null) {
                                      context.read<FcmSenderCubit>().updateApnsPriority(value);
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const SectionHeader('3. Targeting'),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: SegmentedButton<TargetDevice>(
                        segments: const <ButtonSegment<TargetDevice>>[
                          ButtonSegment<TargetDevice>(
                            value: TargetDevice.all,
                            label: Text('All'),
                            icon: Icon(Icons.all_out),
                          ),
                          ButtonSegment<TargetDevice>(
                            value: TargetDevice.android,
                            label: Text('Android'),
                            icon: Icon(Icons.android),
                          ),
                          ButtonSegment<TargetDevice>(
                            value: TargetDevice.ios,
                            label: Text('iOS'),
                            icon: Icon(Icons.apple),
                          ),
                        ],
                        selected: <TargetDevice>{state.targetDevice},
                        onSelectionChanged: isLoading
                            ? null
                            : (Set<TargetDevice> newSelection) {
                                context.read<FcmSenderCubit>().updateTargetDevice(newSelection.first);

                                if (state.targetType != TargetType.allChosenDevices) {
                                  return;
                                }

                                if (newSelection.first == TargetDevice.all) {
                                  _targetValueController.text = DEFAULT_ALL_DEVICES_TOPIC;
                                } else if (newSelection.first == TargetDevice.android) {
                                  _targetValueController.text = DEFAULT_ANDROID_DEVICES_TOPIC;
                                } else if (newSelection.first == TargetDevice.ios) {
                                  _targetValueController.text = DEFAULT_IOS_DEVICES_TOPIC;
                                }
                              },
                        showSelectedIcon: false,
                        style: SegmentedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        RadioListTile<TargetType>(
                          title: const Text(TARGET_TOKEN),
                          value: TargetType.token,
                          groupValue: state.targetType,
                          onChanged: isLoading
                              ? null
                              : (value) {
                                  if (value != null) context.read<FcmSenderCubit>().updateTargetType(value);
                                },
                          contentPadding: EdgeInsets.zero,
                        ),
                        RadioListTile<TargetType>(
                          title: const Text(TARGET_ALL),
                          value: TargetType.allChosenDevices,
                          groupValue: state.targetType,
                          onChanged: isLoading
                              ? null
                              : (value) {
                                  if (value != null) context.read<FcmSenderCubit>().updateTargetType(value);
                                },
                          contentPadding: EdgeInsets.zero,
                        ),
                        Opacity(
                          opacity: 0.4,
                          child: AbsorbPointer(
                            child: RadioListTile<TargetType>(
                              title: const Text(TARGET_TOPIC),
                              value: TargetType.topic,
                              groupValue: state.targetType,
                              onChanged: isLoading
                                  ? null
                                  : (value) {
                                      if (value != null) context.read<FcmSenderCubit>().updateTargetType(value);
                                    },
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _targetValueController,
                      decoration: InputDecoration(
                        labelText: state.targetType == TargetType.token ? 'Device Token' : 'Topic Name',
                        hintText: state.targetType == TargetType.token
                            ? 'Enter device FCM token...'
                            : state.targetType == TargetType.allChosenDevices
                                ? 'Using topic: $DEFAULT_ALL_DEVICES_TOPIC'
                                : 'Enter topic name (e.g., news)',
                        enabled: !isLoading && state.targetType != TargetType.allChosenDevices,
                        filled: state.targetType == TargetType.allChosenDevices,
                        fillColor: state.targetType == TargetType.allChosenDevices ? disabledFillColor : null,
                      ),
                      readOnly: state.targetType == TargetType.allChosenDevices,
                      validator: (value) {
                        if (state.targetType != TargetType.allChosenDevices &&
                            (value == null || value.trim().isEmpty)) {
                          return 'Target ${_targetTypeDescription(state.targetType)} is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    const SectionHeader('4. Setup'),
                    const Text(
                      '🚨 Security Warning: Paste your Service Account JSON content below. Handle this securely.',
                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
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
                      enabled: !isLoading,
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
                      enabled: !isLoading,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Project ID is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SectionHeader('5. Execution Log / API Response'),
                        TextButton(
                          onPressed: isLoading ? null : () => context.read<FcmSenderCubit>().clearLog(),
                          child: const Text('Clear Log'),
                        ),
                      ],
                    ),
                    Container(
                      height: 300,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: logBorderColor),
                        borderRadius: BorderRadius.circular(4),
                        color: logBgColor,
                      ),
                      child: SingleChildScrollView(
                        reverse: true,
                        child: SelectableText(
                          state.logOutput.isEmpty ? 'Log output will appear here...' : state.logOutput,
                          style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: logTextColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 30),
                    const SectionHeader('App Theme'),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.wb_sunny_outlined),
                          label: const Text('Light'),
                          onPressed: () async {
                            widget.themeNotifier.value = ThemeMode.light;

                            final sharedPreferences = await SharedPreferences.getInstance();
                            await PreferencesService(prefs: sharedPreferences).saveThemeMode(ThemeMode.light);
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

                            final sharedPreferences = await SharedPreferences.getInstance();
                            await PreferencesService(prefs: sharedPreferences).saveThemeMode(ThemeMode.dark);
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
              );
            },
          ),
        ),
      ),
    );
  }

  String _targetTypeDescription(TargetType type) {
    switch (type) {
      case TargetType.token:
        return 'Token';
      case TargetType.topic:
        return 'Topic Name';
      case TargetType.allChosenDevices:
        return 'Topic Name (All)';
    }
  }
}
