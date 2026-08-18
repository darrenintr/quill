import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'daos/drawing_pages_dao.dart';
import 'daos/folders_dao.dart';
import 'daos/notes_dao.dart';
import 'daos/tags_dao.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// Root database for Quill.
///
/// Five tables: [Notes], [Folders], [Tags], [NoteTags], [DrawingPages].
/// Heavy assets (drawings, PDFs, images) live on the file system under the
/// app's documents directory and are exposed through repositories in the
/// `data/repositories` layer.
@DriftDatabase(
  tables: [Notes, Folders, Tags, NoteTags, DrawingPages],
  daos: [NotesDao, FoldersDao, TagsDao, DrawingPagesDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor for in-memory test databases. Skips path_provider and the
  /// platform sqlite workaround, so it's safe to use in pure unit tests.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedInbox();
        },
        onUpgrade: (m, from, to) async {
          // v1 → v2: add drawing pages + cloud sync fields.
          if (from < 2) {
            await m.createTable(drawingPages);
            await m.addColumn(notes, notes.kind);
            await m.addColumn(notes, notes.cloudEtag);
            await m.addColumn(notes, notes.cloudProvider);
            await m.addColumn(notes, notes.cloudSyncedAt);
            await m.addColumn(notes, notes.isDirty);
          }
        },
        beforeOpen: (details) async {
          // Enable foreign key constraints so cascading deletes work.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> _seedInbox() async {
    // Seed an "Inbox" folder so first-run users have something to drag
    // notes into.
    await into(folders).insert(
      FoldersCompanion.insert(
        id: 'inbox',
        name: 'Inbox',
        createdAt: DateTime.now(),
      ),
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'quill.sqlite'));

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    // Use the bundled sqlite3 with a temporary directory for the
    // temporary file storage, to avoid hitting platform limits.
    final cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;

    return NativeDatabase.createInBackground(
      file,
      logStatements: false,
    );
  });
}