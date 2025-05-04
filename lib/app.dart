import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'lib.dart';

class MyApp extends StatelessWidget {
  final SharedPreferences sharedPreferences;
  final Box<FcmHistoryEntry> historyBox;
  final ValueNotifier<ThemeMode> themeNotifier;

  const MyApp({
    super.key,
    required this.sharedPreferences,
    required this.historyBox,
    required this.themeNotifier,
  });

  @override
  Widget build(BuildContext context) {
    final preferencesService = PreferencesService(prefs: sharedPreferences);
    final historyRepository = HistoryRepository();
    final httpClient = http.Client();
    final fcmRepositoryAndroid = FcmRepositoryAndroid(httpClient: httpClient);
    final fcmRepositoryIos = FcmRepositoryIos(httpClient: httpClient);

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: preferencesService),
        RepositoryProvider.value(value: historyRepository),
        RepositoryProvider.value(value: fcmRepositoryAndroid),
        RepositoryProvider.value(value: fcmRepositoryIos),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => FcmSenderCubit(
              fcmRepositoryAndroid: context.read<FcmRepositoryAndroid>(),
              fcmRepositoryIos: context.read<FcmRepositoryIos>(),
              preferencesService: context.read<PreferencesService>(),
              historyRepository: context.read<HistoryRepository>(),
            ),
          ),
          BlocProvider(
            create: (context) => HistoryCubit(
              historyRepository: context.read<HistoryRepository>(),
            ),
          ),
        ],
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (_, mode, __) {
            return MaterialApp(
              title: 'FCM Sender',
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: mode,
              home: FcmSenderScreen(themeNotifier: themeNotifier),
            );
          },
        ),
      ),
    );
  }
}
