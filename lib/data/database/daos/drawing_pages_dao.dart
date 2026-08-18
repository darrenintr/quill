import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'drawing_pages_dao.g.dart';

@DriftAccessor(tables: [DrawingPages, Notes])
class DrawingPagesDao extends DatabaseAccessor<AppDatabase>
    with _$DrawingPagesDaoMixin {
  DrawingPagesDao(super.db);

  /// Stream every page for a given note, ordered by [pageIndex].
  Stream<List<DrawingPageRow>> watchForNote(String noteId) {
    return (select(drawingPages)
          ..where((t) => t.noteId.equals(noteId))
          ..orderBy([(t) => OrderingTerm.asc(t.pageIndex)]))
        .watch();
  }

  Future<List<DrawingPageRow>> listForNote(String noteId) {
    return (select(drawingPages)
          ..where((t) => t.noteId.equals(noteId))
          ..orderBy([(t) => OrderingTerm.asc(t.pageIndex)]))
        .get();
  }

  Future<DrawingPageRow?> findById(String id) {
    return (select(drawingPages)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> upsert(DrawingPagesCompanion entry) =>
      into(drawingPages).insertOnConflictUpdate(entry);

  Future<void> updateStrokes({
    required String id,
    required String strokesJson,
  }) {
    return (update(drawingPages)..where((t) => t.id.equals(id))).write(
      DrawingPagesCompanion(
        strokes: Value(strokesJson),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Returns the [id] of the new page so the caller can wire UI to it.
  Future<String> addPage({
    required String noteId,
    required int pageIndex,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final now = DateTime.now();
    await into(drawingPages).insert(
      DrawingPagesCompanion.insert(
        id: id,
        noteId: noteId,
        pageIndex: pageIndex,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  Future<void> deleteById(String id) {
    return (delete(drawingPages)..where((t) => t.id.equals(id))).go();
  }

  Future<int> countForNote(String noteId) async {
    final c = drawingPages.id.count();
    final row = await (selectOnly(drawingPages)
          ..addColumns([c])
          ..where(drawingPages.noteId.equals(noteId)))
        .getSingle();
    return row.read(c) ?? 0;
  }
}