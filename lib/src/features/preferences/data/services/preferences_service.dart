import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../config/constants.dart';

class PreferenceData {
  final String serviceAccountJson;
  final String projectId;
  final TargetType targetType;
  final String targetValue;
  final String analyticsLabel;
  final String androidPriority;
  final String apnsPriority;
  final ThemeMode themeMode;

  const PreferenceData({
    required this.serviceAccountJson,
    required this.projectId,
    required this.targetType,
    required this.targetValue,
    required this.analyticsLabel,
    required this.androidPriority,
    required this.apnsPriority,
    required this.themeMode,
  });
}

class PreferencesService {
  final SharedPreferences _prefs;

  PreferencesService({required SharedPreferences prefs}) : _prefs = prefs;

  Future<PreferenceData> loadPreferences() async {
    final targetTypeString = _prefs.getString(PREFS_KEY_TARGET_TYPE) ?? TARGET_TOKEN;
    final targetType = _stringToTargetType(targetTypeString);
    final themeString = _prefs.getString(PREFS_KEY_THEME) ?? 'dark';

    String targetValue = '';
    if (targetType == TargetType.allChosenDevices) {
      targetValue = DEFAULT_ALL_DEVICES_TOPIC;
    } else {
      targetValue = _prefs.getString(PREFS_KEY_TARGET_VALUE) ?? '';
    }

    return PreferenceData(
      serviceAccountJson: _prefs.getString(PREFS_KEY_SERVICE_ACCOUNT) ?? '',
      projectId: _prefs.getString(PREFS_KEY_PROJECT_ID) ?? DEFAULT_PROJECT_ID,
      targetType: targetType,
      targetValue: targetValue,
      analyticsLabel: _prefs.getString(PREFS_KEY_ANALYTICS_LABEL) ?? '',
      androidPriority: _prefs.getString(PREFS_KEY_ANDROID_PRIORITY) ?? 'DEFAULT',
      apnsPriority: _prefs.getString(PREFS_KEY_APNS_PRIORITY) ?? 'DEFAULT',
      themeMode: themeString == 'light' ? ThemeMode.light : ThemeMode.dark,
    );
  }

  Future<void> saveServiceAccountJson(String value) => _prefs.setString(PREFS_KEY_SERVICE_ACCOUNT, value);
  Future<void> saveProjectId(String value) => _prefs.setString(PREFS_KEY_PROJECT_ID, value);
  Future<void> saveAnalyticsLabel(String value) => _prefs.setString(PREFS_KEY_ANALYTICS_LABEL, value);
  Future<void> saveAndroidPriority(String value) => _prefs.setString(PREFS_KEY_ANDROID_PRIORITY, value);
  Future<void> saveApnsPriority(String value) => _prefs.setString(PREFS_KEY_APNS_PRIORITY, value);

  Future<void> saveTarget({required TargetType type, required String value}) async {
    await _prefs.setString(PREFS_KEY_TARGET_TYPE, _targetTypeToString(type));
    if (type != TargetType.allChosenDevices) {
      await _prefs.setString(PREFS_KEY_TARGET_VALUE, value);
    } else {
      await _prefs.remove(PREFS_KEY_TARGET_VALUE);
    }
  }

  Future<void> saveThemeMode(ThemeMode mode) =>
      _prefs.setString(PREFS_KEY_THEME, mode == ThemeMode.light ? 'light' : 'dark');

  TargetType _stringToTargetType(String value) {
    switch (value) {
      case TARGET_TOKEN:
        return TargetType.token;
      case TARGET_TOPIC:
        return TargetType.topic;
      case TARGET_ALL:
        return TargetType.allChosenDevices;
      default:
        return TargetType.token;
    }
  }

  String _targetTypeToString(TargetType type) {
    switch (type) {
      case TargetType.token:
        return TARGET_TOKEN;
      case TargetType.topic:
        return TARGET_TOPIC;
      case TargetType.allChosenDevices:
        return TARGET_ALL;
    }
  }
}
