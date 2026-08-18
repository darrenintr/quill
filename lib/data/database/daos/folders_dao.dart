import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'folders_dao.g.dart';

@DriftAccessor(tables: [Folders, Notes])
class FoldersDao extends DatabaseAccessor<AppDatabase> with _$FoldersDaoMixin {
  FoldersDao(super.db);

  Stream<List<FolderRow>> watchAll() {
    return (select(folders)
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .watch();
  }

  Stream<List<FolderRow>> watchRoots() {
    return (select(folders)
          ..where((t) => t.parentId.isNull())
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .watch();
  }

  Stream<List<FolderRow>> watchChildren(String parentId) {
    return (select(folders)
          ..where((t) => t.parentId.equals(parentId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .watch();
  }

  Future<FolderRow?> findById(String id) {
    return (select(folders)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsert(FoldersCompanion entry) =>
      into(folders).insertOnConflictUpdate(entry);

  Future<void> rename(String id, String name) {
    return (update(folders)..where((t) => t.id.equals(id)))
        .write(FoldersCompanion(name: Value(name)));
  }

  Future<void> recolor(String id, int color) {
    return (update(folders)..where((t) => t.id.equals(id)))
        .write(FoldersCompanion(color: Value(color)));
  }

  Future<void> deleteById(String id) {
    return (delete(folders)..where((t) => t.id.equals(id))).go();
  }

  /// Notes-per-folder count, surfaced in the sidebar.
  Stream<Map<String, int>> watchCounts() {
    final countExp = notes.id.count();
    final query = selectOnly(notes)
      ..addColumns([notes.folderId, countExp])
      ..where(notes.trashed.equals(false))
      ..groupBy([notes.folderId]);

    return query.watch().map((rows) {
      final out = <String, int>{};
      for (final row in rows) {
        final folderId = row.read(notes.folderId);
        if (folderId != null) {
          out[folderId] = row.read(countExp) ?? 0;
        }
      }
      return out;
    });
  }
}