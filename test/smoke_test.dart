import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quill/app/theme/app_theme.dart';
import 'package:quill/core/providers/app_settings_controller.dart';
import 'package:quill/features/dashboard/presentation/dashboard_page.dart';
import 'package:quill/features/settings/presentation/settings_page.dart';
import 'package:quill/features/search/presentation/search_page.dart';

Future<ProviderContainer> _bootstrapContainer() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWith((ref) async {
        return await SharedPreferences.getInstance();
      }),
    ],
  );
  await container.read(sharedPreferencesProvider.future);
  return container;
}

void main() {
  testWidgets('dashboard page renders', (tester) async {
    final container = await _bootstrapContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const DashboardPage(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Quill'), findsOneWidget);
  });

  testWidgets('settings page renders', (tester) async {
    final container = await _bootstrapContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
  });

  testWidgets('search page renders', (tester) async {
    final container = await _bootstrapContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SearchPage(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
  });
}