import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_settings_controller.dart';
import '../../cloud/presentation/cloud_sync_section.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader(label: 'Appearance'),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Theme'),
            subtitle: Text(_themeLabel(settings.themeMode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final mode = await showModalBottomSheet<ThemeMode>(
                context: context,
                showDragHandle: true,
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(24, 8, 24, 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Theme',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      for (final entry in const [
                        (ThemeMode.system, 'System default'),
                        (ThemeMode.light, 'Light'),
                        (ThemeMode.dark, 'Dark'),
                      ])
                        ListTile(
                          leading: Icon(
                            settings.themeMode == entry.$1
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: settings.themeMode == entry.$1
                                ? Theme.of(ctx).colorScheme.primary
                                : null,
                          ),
                          title: Text(entry.$2),
                          onTap: () => Navigator.pop(ctx, entry.$1),
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              );
              if (mode != null) controller.setThemeMode(mode);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.palette_outlined),
            title: const Text('Dynamic color'),
            subtitle: const Text(
              'Use colors from your wallpaper on supported devices',
            ),
            value: settings.useDynamicColor,
            onChanged: controller.setUseDynamicColor,
          ),
          const Divider(height: 32),
          const CloudSyncSection(),
          const Divider(height: 32),
          _SectionHeader(label: 'About'),
          ListTile(
            leading: const Icon(Icons.edit_note_outlined),
            title: const Text('Quill'),
            subtitle: const Text('Version 0.1.0 · Material You · Made with Flutter'),
          ),
          ListTile(
            leading: const Icon(Icons.code_outlined),
            title: const Text('Open source'),
            subtitle: const Text('GPL-3.0 · github.com/quill-app/quill'),
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'System default',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}