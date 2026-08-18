import 'dart:convert';

import '../../../data/database/app_database.dart';

/// Wire format for a synced note.
///
/// Versioned ([version]) so future format changes don't crash old clients.
/// Drawing notes have a separate [drawingPages] list — each page carries its
/// own strokes JSON.
class NotePayload {
  const NotePayload({
    required this.version,
    required this.id,
    required this.folderId,
    required this.kind,
    required this.title,
    required this.contentJson,
    required this.preview,
    required this.color,
    required this.pinned,
    required this.archived,
    required this.trashed,
    required this.createdAt,
    required this.updatedAt,
    required this.drawingPages,
  });

  final int version;
  final String id;
  final String? folderId;
  final String kind;
  final String title;
  final String contentJson;
  final String preview;
  final int color;
  final bool pinned;
  final bool archived;
  final bool trashed;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<DrawingPagePayload> drawingPages;

  static const int currentVersion = 1;

  Map<String, dynamic> toJson() => {
        'v': version,
        'id': id,
        'folderId': folderId,
        'kind': kind,
        'title': title,
        'contentJson': contentJson,
        'preview': preview,
        'color': color,
        'pinned': pinned,
        'archived': archived,
        'trashed': trashed,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'pages': drawingPages.map((p) => p.toJson()).toList(),
      };

  String encode() => jsonEncode(toJson());

  static NotePayload fromJson(Map<String, dynamic> json) => NotePayload(
        version: json['v'] as int? ?? 1,
        id: json['id'] as String,
        folderId: json['folderId'] as String?,
        kind: json['kind'] as String? ?? 'text',
        title: json['title'] as String? ?? 'Untitled',
        contentJson: json['contentJson'] as String? ?? '[]',
        preview: json['preview'] as String? ?? '',
        color: (json['color'] as int?) ?? 0xFF6750A4,
        pinned: json['pinned'] as bool? ?? false,
        archived: json['archived'] as bool? ?? false,
        trashed: json['trashed'] as bool? ?? false,
        createdAt:
            DateTime.parse(json['createdAt'] as String? ?? DateTime.now().toIso8601String()),
        updatedAt:
            DateTime.parse(json['updatedAt'] as String? ?? DateTime.now().toIso8601String()),
        drawingPages: ((json['pages'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(DrawingPagePayload.fromJson)
            .toList(),
      );

  static NotePayload decode(String source) =>
      fromJson(jsonDecode(source) as Map<String, dynamic>);
}

/// Wire format for a single drawing page. Lives in its own file so updates
/// to one page don't bloat the parent note file.
class DrawingPagePayload {
  const DrawingPagePayload({
    required this.id,
    required this.noteId,
    required this.pageIndex,
    required this.strokes,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String noteId;
  final int pageIndex;
  final String strokes;
  final int color;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'noteId': noteId,
        'pageIndex': pageIndex,
        'strokes': strokes,
        'color': color,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  String encode() => jsonEncode(toJson());

  static DrawingPagePayload fromJson(Map<String, dynamic> json) => DrawingPagePayload(
        id: json['id'] as String,
        noteId: json['noteId'] as String,
        pageIndex: (json['pageIndex'] as num).toInt(),
        strokes: json['strokes'] as String? ?? '[]',
        color: (json['color'] as int?) ?? 0xFFFFFFFF,
        createdAt:
            DateTime.parse(json['createdAt'] as String? ?? DateTime.now().toIso8601String()),
        updatedAt:
            DateTime.parse(json['updatedAt'] as String? ?? DateTime.now().toIso8601String()),
      );

  static DrawingPagePayload decode(String source) =>
      fromJson(jsonDecode(source) as Map<String, dynamic>);

  factory DrawingPagePayload.fromRow(DrawingPageRow row) => DrawingPagePayload(
        id: row.id,
        noteId: row.noteId,
        pageIndex: row.pageIndex,
        strokes: row.strokes,
        color: row.color,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );
}