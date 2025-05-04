// ignore_for_file: constant_identifier_names

// --- Configuration ---
const String DEFAULT_PROJECT_ID = 'super-app-staging-3154d'; // Your Default Project ID
const String TARGET_TOKEN = 'Specific Device (Token)';
const String TARGET_TOPIC = 'Specific Topic';
const String TARGET_ALL = 'All Devices (via Topic)';
const String DEFAULT_ALL_DEVICES_TOPIC = 'all';

enum TargetType { token, topic, all }

enum TargetDevice { ios, android }

// --- Preference Keys ---
const String PREFS_KEY_SERVICE_ACCOUNT = 'serviceAccountJson';
const String PREFS_KEY_PROJECT_ID = 'projectId';
const String PREFS_KEY_TARGET_TYPE = 'selectedTargetType';
const String PREFS_KEY_TARGET_VALUE = 'targetValue';
const String PREFS_KEY_ANALYTICS_LABEL = 'analyticsLabel';
const String PREFS_KEY_ANDROID_PRIORITY = 'selectedAndroidPriority';
const String PREFS_KEY_APNS_PRIORITY = 'selectedApnsPriority';
const String PREFS_KEY_THEME = 'themeKey'; // Keep for theme persistence

// --- Hive ---
const String HISTORY_BOX_NAME = 'fcm_send_history';

// --- API ---
const String FCM_SEND_URL = 'https://fcm.googleapis.com/v1/projects/{projectId}/messages:send';
const List<String> FCM_SCOPES = ['https://www.googleapis.com/auth/firebase.messaging'];
