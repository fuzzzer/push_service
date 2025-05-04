import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:push_service/app.dart';
import 'package:push_service/src/config/constants.dart';
import 'package:push_service/src/features/common/models/fcm_history_entry.dart';
import 'package:push_service/src/features/preferences/data/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(FcmHistoryEntryAdapter());
  final historyBox = await Hive.openBox<FcmHistoryEntry>(HISTORY_BOX_NAME);

  final sharedPreferences = await SharedPreferences.getInstance();

  final initialThemeMode =
      await PreferencesService(prefs: sharedPreferences).loadPreferences().then((data) => data.themeMode);
  final themeNotifier = ValueNotifier(initialThemeMode);

  runApp(
    MyApp(
      sharedPreferences: sharedPreferences,
      historyBox: historyBox,
      themeNotifier: themeNotifier,
    ),
  );
}
