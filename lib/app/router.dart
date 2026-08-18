import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/editor/presentation/editor_page.dart';
import '../features/folders/presentation/folder_page.dart';
import '../features/home/presentation/app_shell.dart';
import '../features/search/presentation/search_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/tags/presentation/tag_page.dart';

/// Route names are kept as constants so screens can reference them safely.
class AppRoutes {
  static const dashboard = '/';
  static const folderPattern = '/folder/:id';
  static const tagPattern = '/tag/:id';
  static const search = '/search';
  static const editorPattern = '/note/:id';
  static const settings = '/settings';

  static String folderById(String id) => '/folder/$id';
  static String tagById(String id) => '/tag/$id';
  static String editorById(String id) => '/note/$id';
}

GoRouter buildRouter() {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.dashboard,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          // Branch 0 — Home / folders.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                builder: (_, _) => const DashboardPage(),
                routes: [
                  GoRoute(
                    path: 'folder/:id',
                    builder: (_, state) => FolderPage(
                      folderId: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: 'tag/:id',
                    builder: (_, state) => TagPage(
                      tagId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Branch 1 — Search.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.search,
                builder: (_, _) => const SearchPage(),
              ),
            ],
          ),
          // Branch 2 — Settings.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (_, _) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
      // Top-level editor — opens over the shell so it can span the screen.
      GoRoute(
        path: AppRoutes.editorPattern,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => EditorPage(noteId: state.pathParameters['id']!),
      ),
    ],
  );
}

final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKey = GlobalKey<NavigatorState>();