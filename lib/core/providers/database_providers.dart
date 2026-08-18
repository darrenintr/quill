import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/database/daos/folders_dao.dart';
import '../../data/database/daos/notes_dao.dart';
import '../../data/database/daos/tags_dao.dart';

/// The single shared database instance. Opening it is async; the provider
/// auto-disposes the instance on app shutdown.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final notesDaoProvider = Provider<NotesDao>(
  (ref) => ref.watch(databaseProvider).notesDao,
);

final foldersDaoProvider = Provider<FoldersDao>(
  (ref) => ref.watch(databaseProvider).foldersDao,
);

final tagsDaoProvider = Provider<TagsDao>(
  (ref) => ref.watch(databaseProvider).tagsDao,
);