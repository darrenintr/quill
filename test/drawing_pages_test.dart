import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';

import 'package:quill/data/database/app_database.dart';
import 'package:quill/data/database/daos/drawing_pages_dao.dart';
import 'package:quill/features/canvas/domain/brush.dart';
import 'package:quill/features/canvas/domain/stroke.dart';

void main() {
  late AppDatabase db;
  late DrawingPagesDao pagesDao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    pagesDao = db.drawingPagesDao;
  });

  tearDown(() async {
    await db.close();
  });

  Future<String> _seedNote(String id) async {
    final now = DateTime.now();
    await db.notesDao.upsert(NotesCompanion.insert(
      id: id,
      title: const Value('Test notebook'),
      kind: const Value('drawing'),
      createdAt: now,
      updatedAt: now,
    ));
    return id;
  }

  test('addPage creates a blank page and assigns an id', () async {
    await _seedNote('n1');
    final pageId = await pagesDao.addPage(noteId: 'n1', pageIndex: 0);
    final fetched = await pagesDao.findById(pageId);
    expect(fetched, isNotNull);
    expect(fetched!.pageIndex, 0);
    expect(fetched.strokes, '[]');
  });

  test('updateStrokes persists serialized stroke list', () async {
    await _seedNote('n2');
    final pageId = await pagesDao.addPage(noteId: 'n2', pageIndex: 0);
    const brush = Brush(kind: BrushKind.pen, color: Color(0xFF000000), size: 4, opacity: 1);
    final strokes = [
      Stroke(brush: brush, points: const [
        StrokePoint(x: 0, y: 0, pressure: 0.5),
        StrokePoint(x: 5, y: 5, pressure: 0.7),
      ]),
    ];
    await pagesDao.updateStrokes(
      id: pageId,
      strokesJson: strokesToJson(strokes),
    );
    final fetched = await pagesDao.findById(pageId);
    expect(fetched, isNotNull);
    final restored = strokesFromJson(fetched!.strokes);
    expect(restored.length, 1);
    expect(restored.first.points.length, 2);
  });

  test('deleting a note cascades to its pages', () async {
    await _seedNote('n3');
    final id1 = await pagesDao.addPage(noteId: 'n3', pageIndex: 0);
    final id2 = await pagesDao.addPage(noteId: 'n3', pageIndex: 1);
    expect(await pagesDao.countForNote('n3'), 2);
    await db.notesDao.deletePermanently('n3');
    expect(await pagesDao.findById(id1), isNull);
    expect(await pagesDao.findById(id2), isNull);
  });

  test('listForNote orders by pageIndex', () async {
    await _seedNote('n4');
    await pagesDao.addPage(noteId: 'n4', pageIndex: 2);
    await pagesDao.addPage(noteId: 'n4', pageIndex: 0);
    await pagesDao.addPage(noteId: 'n4', pageIndex: 1);
    final pages = await pagesDao.listForNote('n4');
    expect(pages.map((p) => p.pageIndex).toList(), [0, 1, 2]);
  });
}