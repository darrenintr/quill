import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quill/data/database/app_database.dart';
import 'package:quill/data/database/daos/notes_dao.dart';
import 'package:quill/data/database/daos/folders_dao.dart';
import 'package:quill/data/database/daos/tags_dao.dart';

/// In-memory Drift database for fast unit tests.
AppDatabase _memory() => AppDatabase.forTesting(NativeDatabase.memory());

void main() {
  late AppDatabase db;
  late NotesDao notes;
  late FoldersDao folders;
  late TagsDao tags;

  setUp(() {
    db = _memory();
    notes = db.notesDao;
    folders = db.foldersDao;
    tags = db.tagsDao;
  });

  tearDown(() async => db.close());

  test('inserts and reads back a note', () async {
    final id = 'n1';
    await notes.upsert(NotesCompanion.insert(
      id: id,
      title: const Value('Hello world'),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ));

    final fetched = await notes.findById(id);
    expect(fetched, isNotNull);
    expect(fetched!.title, 'Hello world');
    expect(fetched.preview, '');
    expect(fetched.pinned, isFalse);
  });

  test('updates note content', () async {
    final id = 'n2';
    await notes.upsert(NotesCompanion.insert(
      id: id,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ));
    await notes.updateContent(
      id: id,
      title: 'My revised title',
      contentJson: '[{"insert":"Hello"}]',
      preview: 'Hello',
    );
    final fetched = await notes.findById(id);
    expect(fetched!.title, 'My revised title');
    expect(fetched.preview, 'Hello');
  });

  test('pins and unpins notes', () async {
    final id = 'n3';
    await notes.upsert(NotesCompanion.insert(
      id: id,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ));
    await notes.setPinned(id, true);
    expect((await notes.findById(id))!.pinned, isTrue);
    await notes.setPinned(id, false);
    expect((await notes.findById(id))!.pinned, isFalse);
  });

  test('folder CRUD', () async {
    final folderId = 'f1';
    await folders.upsert(FoldersCompanion.insert(
      id: folderId,
      name: 'Daily',
      createdAt: DateTime(2026, 1, 1),
    ));
    expect((await folders.findById(folderId))!.name, 'Daily');
    await folders.rename(folderId, 'Daily Notes');
    expect((await folders.findById(folderId))!.name, 'Daily Notes');
    await folders.deleteById(folderId);
    expect(await folders.findById(folderId), isNull);
  });

  test('tag ensure is idempotent', () async {
    final t = await tags.ensure('ideas');
    final same = await tags.ensure('ideas');
    expect(same.id, t.id);
  });

  test('full-text search matches title', () async {
    await notes.upsert(NotesCompanion.insert(
      id: 's1',
      title: const Value('Quill design notes'),
      preview: const Value('Material 3 dashboard'),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ));
    await notes.upsert(NotesCompanion.insert(
      id: 's2',
      title: const Value('Lunch recipe'),
      preview: const Value('tofu and rice'),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ));
    final results = await notes.search('quill').first;
    expect(results.length, 1);
    expect(results.first.id, 's1');
  });
}