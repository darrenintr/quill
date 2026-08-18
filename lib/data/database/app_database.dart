import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'daos/folders_dao.dart';
import 'daos/notes_dao.dart';
import 'daos/tags_dao.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// Root database for Quill.
///
/// Three tables ([Notes], [Folders], [Tags]) and one join table ([NoteTags]).
/// Heavy assets (drawings, PDFs, images) live on the file system under the
/// app's documents directory and are exposed through repositories in the
/// `data/repositories` layer.
@DriftDatabase(
  tables: [Notes, Folders, Tags, NoteTags],
  daos: [NotesDao, FoldersDao, TagsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor for in-memory test databases. Skips path_provider and the
  /// platform sqlite workaround, so it's safe to use in pure unit tests.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Seed an "Inbox" folder so first-run users have something to drag
          // notes into.
          await into(folders).insert(
            FoldersCompanion.insert(
              id: 'inbox',
              name: 'Inbox',
              createdAt: DateTime.now(),
            ),
          );
        },
      );
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