import 'package:drift/drift.dart';

/// Folder hierarchy. Self-referential [parentId] enables a tree.
@DataClassName('FolderRow')
class Folders extends Table {
  TextColumn get id => text()();
  TextColumn get parentId => text().nullable().references(Folders, #id,
      onDelete: KeyAction.setNull)();
  TextColumn get name => text()();
  IntColumn get color => integer().withDefault(const Constant(0xFF6750A4))();
  IntColumn get iconCodePoint =>
      integer().withDefault(const Constant(0xe2c7))(); // Material folder icon
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Core note table. The `contentJson` blob stores a Quill Delta document
/// (the rich-text representation). Large binary payloads (drawings, attached
/// images, PDF pages) live on the file system and are referenced by [blobId].
///
/// [kind] is 'text' or 'drawing' — a note either has a Quill Delta body
/// or a list of [DrawingPage]s, never both.
///
/// Cloud sync fields:
///   * [cloudEtag] — opaque version token returned by the cloud provider
///   * [cloudSyncedAt] — wall-clock time of the last successful upload
///   * [cloudProvider] — 'onedrive' / 'icloud' / null
///   * [isDirty] — local change pending upload (true on edit, cleared on sync)
@DataClassName('NoteRow')
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get folderId => text().nullable().references(Folders, #id,
      onDelete: KeyAction.setNull)();
  TextColumn get kind =>
      text().withDefault(const Constant('text'))(); // 'text' | 'drawing'
  TextColumn get title => text().withDefault(const Constant('Untitled'))();
  TextColumn get contentJson => text().withDefault(const Constant('[]'))();
  TextColumn get preview => text().withDefault(const Constant(''))();
  TextColumn get blobId => text().nullable()();
  IntColumn get color => integer().withDefault(const Constant(0xFF6750A4))();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  BoolColumn get trashed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  // Cloud sync — see doc above.
  TextColumn get cloudEtag => text().nullable()();
  TextColumn get cloudProvider => text().nullable()();
  DateTimeColumn get cloudSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One drawing page in a notebook note. [strokes] is a JSON-encoded list of
/// Stroke objects (see lib/features/canvas/domain/stroke.dart). Strokes are
/// stored as vectors (not bitmaps) so the canvas stays crisp at any zoom.
@DataClassName('DrawingPageRow')
class DrawingPages extends Table {
  TextColumn get id => text()();
  TextColumn get noteId => text().references(Notes, #id,
      onDelete: KeyAction.cascade)();
  IntColumn get pageIndex => integer()();
  TextColumn get strokes => text().withDefault(const Constant('[]'))();
  IntColumn get color =>
      integer().withDefault(const Constant(0xFFFFFFFF))(); // page tint
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Tags are simple labels, unique by lowercase [name].
@DataClassName('TagRow')
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  IntColumn get color => integer().withDefault(const Constant(0xFF6750A4))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Many-to-many join between notes and tags.
@DataClassName('NoteTagRow')
class NoteTags extends Table {
  TextColumn get noteId => text().references(Notes, #id,
      onDelete: KeyAction.cascade)();
  TextColumn get tagId => text().references(Tags, #id,
      onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => {noteId, tagId};
}