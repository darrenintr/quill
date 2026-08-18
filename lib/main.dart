import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/providers/app_settings_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitDown,
  ]);

  final container = ProviderContainer();
  // Warm up preferences so the theme picks its initial values on first frame.
  await container.read(sharedPreferencesProvider.future);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const QuillApp(),
    ),
  );
}