import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quill/data/database/app_database.dart';
import 'package:quill/features/cloud/application/sync_engine.dart';
import 'package:quill/features/cloud/data/icloud_drive_provider.dart';
import 'package:quill/features/cloud/domain/cloud_provider.dart';
import 'package:quill/features/cloud/domain/note_payload.dart';

/// In-memory CloudProvider used to exercise the SyncEngine without
/// touching the network. Behaves like a tiny key-value store.
class _FakeCloudProvider implements CloudProvider {
  _FakeCloudProvider();
  final Map<String, Uint8List> _files = {};
  final Map<String, String> _etags = {};
  int _seq = 0;
  bool signedIn = true;

  @override
  CloudProviderId get id => CloudProviderId.icloud;

  @override
  String get displayName => 'FakeCloud';

  @override
  bool get isAvailable => true;

  @override
  Future<CloudAuthState> getAuthState() async => CloudAuthState(signedIn: signedIn);

  @override
  Future<CloudAuthState> signIn() async {
    signedIn = true;
    return getAuthState();
  }

  @override
  Future<void> signOut() async {
    signedIn = false;
  }

  String _nextEtag() {
    _seq++;
    return 'e$_seq';
  }

  @override
  Future<CloudFileMetadata> upload({
    required String path,
    required Uint8List bytes,
    String? expectedEtag,
  }) async {
    if (expectedEtag != null && _etags[path] != null && _etags[path] != expectedEtag) {
      throw CloudException('etag mismatch', statusCode: 412);
    }
    final etag = _nextEtag();
    _files[path] = bytes;
    _etags[path] = etag;
    return CloudFileMetadata(
      id: etag,
      path: path,
      etag: etag,
      modifiedAt: DateTime.now(),
    );
  }

  @override
  Future<CloudDownloadResult?> download(String path) async {
    final bytes = _files[path];
    if (bytes == null) return null;
    return CloudDownloadResult(
      bytes: bytes,
      metadata: CloudFileMetadata(
        id: _etags[path]!,
        path: path,
        etag: _etags[path]!,
        modifiedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<CloudFileMetadata?> stat(String path) async {
    if (_files[path] == null) return null;
    return CloudFileMetadata(
      id: _etags[path]!,
      path: path,
      etag: _etags[path]!,
      modifiedAt: DateTime.now(),
    );
  }

  @override
  Future<List<CloudFileMetadata>> list({String prefix = ''}) async {
    return _files.keys
        .where((k) => k.startsWith(prefix))
        .map((k) => CloudFileMetadata(
              id: _etags[k]!,
              path: k,
              etag: _etags[k]!,
              modifiedAt: DateTime.now(),
            ))
        .toList();
  }

  @override
  Future<void> delete(String path) async {
    _files.remove(path);
    _etags.remove(path);
  }
}

void main() {
  late AppDatabase db;
  late SyncEngine engine;
  late _FakeCloudProvider cloud;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    cloud = _FakeCloudProvider();
    engine = SyncEngine(
      provider: cloud,
      notesDao: db.notesDao,
      pagesDao: db.drawingPagesDao,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<String> seedNote({String? folderId, String title = 'Test', String kind = 'text'}) async {
    final id = 'n_${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now();
    await db.notesDao.upsert(NotesCompanion.insert(
      id: id,
      folderId: folderId == null ? const Value.absent() : Value(folderId),
      title: Value(title),
      kind: Value(kind),
      contentJson: const Value('[{"insert":"hello"}]'),
      createdAt: now,
      updatedAt: now,
    ));
    return id;
  }

  test('pushDirty uploads every local note and stamps the etag', () async {
    final id = await seedNote(title: 'one');
    final result = await engine.pushDirty();
    expect(result.uploaded, 1);
    expect(result.failed, 0);
    final row = await db.notesDao.findById(id);
    expect(row, isNotNull);
    expect(row!.cloudEtag, isNotNull);
    expect(row.cloudProvider, 'icloud');
    expect(row.isDirty, false);
  });

  test('pushDirty is idempotent when nothing is dirty', () async {
    await seedNote(title: 'one');
    final first = await engine.pushDirty();
    expect(first.uploaded, 1);
    final second = await engine.pushDirty();
    expect(second.uploaded, 0);
  });

  test('pull merges remote file newer than local with last-write-wins', () async {
    // Seed local-only with a stale updatedAt.
    final id = await seedNote(title: 'old-local');
    final row = await db.notesDao.findById(id);
    expect(row, isNotNull);
    // Force local to look old.
    await db.notesDao.upsert(NotesCompanion(
      id: Value(id),
      title: Value(row!.title),
      contentJson: Value(row.contentJson),
      createdAt: Value(row.createdAt),
      updatedAt: Value(DateTime.now().subtract(const Duration(days: 2))),
    ));
    // Push the (old) version to cloud.
    await engine.pushDirty();

    // Manually replace the remote with a "newer" version.
    final newPayload = NotePayload(
      version: 1,
      id: id,
      folderId: null,
      kind: 'text',
      title: 'newer-remote',
      contentJson: '[{"insert":"remote wins"}]',
      preview: 'remote wins',
      color: 0xFF6750A4,
      pinned: false,
      archived: false,
      trashed: false,
      createdAt: row.createdAt,
      updatedAt: DateTime.now().add(const Duration(hours: 1)),
      drawingPages: const [],
    );
    final encoded = Uint8List.fromList(newPayload.encode().codeUnits);
    await cloud.upload(path: 'notes/$id.qnote.json', bytes: encoded);

    // Pull should overwrite local.
    final result = await engine.pull();
    expect(result.downloaded, 1);
    final merged = await db.notesDao.findById(id);
    expect(merged!.title, 'newer-remote');
  });

  test('pull does not overwrite newer local notes', () async {
    final id = await seedNote(title: 'fresh');
    await engine.pushDirty();
    // Remote now has the note with the same updatedAt. Bump local to "newer"
    // AND mark it dirty so the heal-pull path doesn't fire.
    final now = DateTime.now();
    await db.notesDao.upsert(NotesCompanion(
      id: Value(id),
      title: const Value('fresh'),
      contentJson: const Value('[{"insert":"local edit"}]'),
      createdAt: Value(now),
      updatedAt: Value(DateTime.now().add(const Duration(hours: 5))),
      isDirty: const Value(true),
    ));
    final result = await engine.pull();
    expect(result.downloaded, 0);
    final local = await db.notesDao.findById(id);
    expect(local!.contentJson, contains('local edit'));
  });

  test('drawing notes round-trip through the cloud', () async {
    final id = await seedNote(title: 'nb', kind: 'drawing');
    await db.drawingPagesDao.addPage(noteId: id, pageIndex: 0);
    await db.drawingPagesDao.updateStrokes(
      id: (await db.drawingPagesDao.listForNote(id)).first.id,
      strokesJson: '[{"id":"s1","brush":{"kind":"pen","color":-16777216,"size":4,"opacity":1},'
          '"points":[{"x":0,"y":0,"p":0.5}]}]',
    );
    final result = await engine.pushDirty();
    expect(result.uploaded, 1);
    expect(cloud._files.containsKey('notes/$id.qnote.json'), true);

    // Delete local pages, then pull to restore.
    final pages = await db.drawingPagesDao.listForNote(id);
    for (final p in pages) {
      await db.drawingPagesDao.deleteById(p.id);
    }
    await engine.pull();
    final restored = await db.drawingPagesDao.listForNote(id);
    expect(restored.length, 1);
    expect(restored.first.strokes, contains('"s1"'));
  });
}