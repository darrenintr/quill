import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as fq;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/app_settings_controller.dart';
import '../core/providers/database_providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class QuillApp extends ConsumerStatefulWidget {
  const QuillApp({super.key});

  @override
  ConsumerState<QuillApp> createState() => _QuillAppState();
}

class _QuillAppState extends ConsumerState<QuillApp> {
  late final _router = buildRouter();

  @override
  void initState() {
    super.initState();
    // Eagerly open the database to make the first frame snappy.
    ref.read(databaseProvider);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final lightScheme = settings.useDynamicColor && lightDynamic != null
            ? lightDynamic.harmonized()
            : ColorScheme.fromSeed(seedColor: AppTheme.brandSeed);
        final darkScheme = settings.useDynamicColor && darkDynamic != null
            ? darkDynamic.harmonized()
            : ColorScheme.fromSeed(
                seedColor: AppTheme.brandSeed,
                brightness: Brightness.dark,
              );

        return MaterialApp.router(
          title: 'Quill',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(seed: lightScheme.primary).copyWith(
            colorScheme: lightScheme,
          ),
          darkTheme: AppTheme.dark(seed: darkScheme.primary).copyWith(
            colorScheme: darkScheme,
          ),
          themeMode: settings.themeMode,
          localizationsDelegates: const [
            ...fq.FlutterQuillLocalizations.localizationsDelegates,
          ],
          supportedLocales: const [
            Locale('en', 'US'),
            Locale('zh', 'CN'),
          ],
          routerConfig: _router,
        );
      },
    );
  }
}