import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'tags_dao.g.dart';

@DriftAccessor(tables: [Tags, NoteTags, Notes])
class TagsDao extends DatabaseAccessor<AppDatabase> with _$TagsDaoMixin {
  TagsDao(super.db);

  Stream<List<TagRow>> watchAll() {
    return (select(tags)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<TagRow?> findByName(String name) {
    return (select(tags)..where((t) => t.name.equals(name))).getSingleOrNull();
  }

  Future<TagRow> ensure(String name, {int? color}) async {
    final existing = await findByName(name);
    if (existing != null) return existing;
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await into(tags).insert(
      TagsCompanion.insert(
        id: id,
        name: name,
        color: color == null ? const Value.absent() : Value(color),
        createdAt: DateTime.now(),
      ),
    );
    return (select(tags)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<void> rename(String id, String name) {
    return (update(tags)..where((t) => t.id.equals(id)))
        .write(TagsCompanion(name: Value(name)));
  }

  Future<void> recolor(String id, int color) {
    return (update(tags)..where((t) => t.id.equals(id)))
        .write(TagsCompanion(color: Value(color)));
  }

  Future<void> deleteById(String id) {
    return (delete(tags)..where((t) => t.id.equals(id))).go();
  }

  /// Notes per tag count for sidebar display.
  Stream<Map<String, int>> watchCounts() {
    final countExp = noteTags.tagId.count();
    final query = selectOnly(noteTags)
      ..addColumns([noteTags.tagId, countExp])
      ..groupBy([noteTags.tagId]);

    return query.watch().map((rows) {
      final out = <String, int>{};
      for (final row in rows) {
        out[row.read(noteTags.tagId)!] = row.read(countExp) ?? 0;
      }
      return out;
    });
  }

  /// Notes carrying the supplied tag id.
  Stream<List<NoteRow>> watchNotesForTag(String tagId) {
    final query = select(notes).join([
      innerJoin(noteTags, noteTags.noteId.equalsExp(notes.id)),
    ])
      ..where(noteTags.tagId.equals(tagId) & notes.trashed.equals(false))
      ..orderBy([OrderingTerm.desc(notes.updatedAt)]);
    return query.watch().map((rows) => rows.map((r) => r.readTable(notes)).toList());
  }
}