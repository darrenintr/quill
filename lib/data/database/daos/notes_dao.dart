import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'notes_dao.g.dart';

@DriftAccessor(tables: [Notes, NoteTags, Tags, Folders])
class NotesDao extends DatabaseAccessor<AppDatabase> with _$NotesDaoMixin {
  NotesDao(super.db);

  /// All notes (including trashed/archived) ordered by most-recently-updated.
  Stream<List<NoteRow>> watchAll({
    bool includeArchived = false,
    bool includeTrashed = false,
  }) {
    final query = select(notes);
    if (!includeArchived) {
      query.where((t) => t.archived.equals(false));
    }
    if (!includeTrashed) {
      query.where((t) => t.trashed.equals(false));
    }
    query.orderBy([
      (t) => OrderingTerm.desc(t.pinned),
      (t) => OrderingTerm.desc(t.updatedAt),
    ]);
    return query.watch();
  }

  /// Notes that live in the supplied folder (or all top-level if [folderId] is
  /// null).
  Stream<List<NoteRow>> watchInFolder(String? folderId) {
    final query = select(notes)
      ..where((t) => t.trashed.equals(false) & t.archived.equals(false));
    if (folderId == null) {
      query.where((t) => t.folderId.isNull());
    } else {
      query.where((t) => t.folderId.equals(folderId));
    }
    query.orderBy([
      (t) => OrderingTerm.desc(t.pinned),
      (t) => OrderingTerm.desc(t.updatedAt),
    ]);
    return query.watch();
  }

  /// Pinned notes shown on the dashboard.
  Stream<List<NoteRow>> watchPinned() {
    return (select(notes)
          ..where((t) =>
              t.pinned.equals(true) &
              t.trashed.equals(false) &
              t.archived.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  Future<NoteRow?> findById(String id) {
    return (select(notes)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Stream<NoteRow?> watchById(String id) {
    return (select(notes)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  Future<void> upsert(NotesCompanion entry) => into(notes).insertOnConflictUpdate(entry);

  Future<void> updateContent({
    required String id,
    required String title,
    required String contentJson,
    required String preview,
  }) async {
    await (update(notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        title: Value(title),
        contentJson: Value(contentJson),
        preview: Value(preview),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setPinned(String id, bool pinned) {
    return (update(notes)..where((t) => t.id.equals(id)))
        .write(NotesCompanion(pinned: Value(pinned)));
  }

  Future<void> setArchived(String id, bool archived) {
    return (update(notes)..where((t) => t.id.equals(id)))
        .write(NotesCompanion(archived: Value(archived)));
  }

  Future<void> setTrashed(String id, bool trashed) {
    return (update(notes)..where((t) => t.id.equals(id)))
        .write(NotesCompanion(trashed: Value(trashed)));
  }

  Future<void> moveToFolder(String id, String? folderId) {
    return (update(notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        folderId: Value(folderId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deletePermanently(String id) {
    return (delete(notes)..where((t) => t.id.equals(id))).go();
  }

  // --- Tags ---

  Stream<List<TagRow>> watchTagsForNote(String noteId) {
    final query = select(tags).join([
      innerJoin(noteTags, noteTags.tagId.equalsExp(tags.id)),
    ])
      ..where(noteTags.noteId.equals(noteId))
      ..orderBy([OrderingTerm.asc(tags.name)]);
    return query.watch().map((rows) => rows.map((r) => r.readTable(tags)).toList());
  }

  Future<List<TagRow>> getTagsForNote(String noteId) async {
    final query = select(tags).join([
      innerJoin(noteTags, noteTags.tagId.equalsExp(tags.id)),
    ])
      ..where(noteTags.noteId.equals(noteId));
    final rows = await query.get();
    return rows.map((r) => r.readTable(tags)).toList();
  }

  Future<void> attachTag(String noteId, String tagId) {
    return into(noteTags).insert(
      NoteTagsCompanion.insert(noteId: noteId, tagId: tagId),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<void> detachTag(String noteId, String tagId) {
    return (delete(noteTags)
          ..where((t) => t.noteId.equals(noteId) & t.tagId.equals(tagId)))
        .go();
  }

  Future<void> replaceTags(String noteId, List<String> tagIds) async {
    await transaction(() async {
      await (delete(noteTags)..where((t) => t.noteId.equals(noteId))).go();
      for (final tagId in tagIds) {
        await into(noteTags).insert(
          NoteTagsCompanion.insert(noteId: noteId, tagId: tagId),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  /// Simple LIKE-based full-text search. SQLite FTS5 would be better at scale;
  /// this keeps the MVP dependency-free.
  Stream<List<NoteRow>> search(String query) {
    final escaped = '%${query.replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
    return (select(notes)
          ..where((t) =>
              (t.title.like(escaped) | t.preview.like(escaped)) &
              t.trashed.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }
}