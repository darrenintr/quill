import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/daos/drawing_pages_dao.dart';
import '../../../data/database/daos/folders_dao.dart';
import '../../../data/database/daos/notes_dao.dart';
import '../domain/cloud_provider.dart';
import '../domain/note_payload.dart';

/// The orchestrator that bridges the local Drift database with a
/// [CloudProvider]. Responsibilities:
///   * Watch the local notes table for dirty rows and push them up.
///   * On a full reconcile pass, pull the remote listing and merge
///     non-existent or newer remote files into the local DB.
///   * Resolve conflicts with last-write-wins: whichever side has a more
///     recent [updatedAt] wins.
///
/// The engine is provider-agnostic — pass any [CloudProvider] at
/// construction time and the same engine handles OneDrive, iCloud Drive, or
/// any future backend.
class SyncEngine {
  SyncEngine({
    required this.provider,
    required this.notesDao,
    required this.pagesDao,
    this.foldersDao,
  });

  final CloudProvider provider;
  final NotesDao notesDao;
  final DrawingPagesDao pagesDao;
  final FoldersDao? foldersDao;

  /// Streams the latest sync result so the UI can show toasts / spinners.
  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;

  bool _running = false;

  /// Pushes every locally-dirty note up to the cloud. Returns when there are
  /// no more dirty notes OR an error halts the loop. Safe to call repeatedly.
  Future<SyncResult> pushDirty() async {
    if (_running) {
      return SyncResult(skipped: true, reason: 'already running');
    }
    _running = true;
    _statusController.add(const SyncStatus(syncing: true, phase: 'pushing'));
    int uploaded = 0;
    int failed = 0;
    try {
      final dirty = await notesDao.findDirty(provider: _providerName());
      for (final note in dirty) {
        try {
          await _uploadNote(note);
          uploaded++;
        } catch (e) {
          failed++;
          _statusController.add(SyncStatus(
            syncing: false,
            phase: 'push',
            error: e.toString(),
          ));
          break; // Don't hammer the API if one fails.
        }
      }
      _statusController.add(SyncStatus(syncing: false, phase: 'pushed'));
      return SyncResult(uploaded: uploaded, failed: failed);
    } finally {
      _running = false;
    }
  }

  /// Lists every remote file under the Quill folder and applies last-write-wins
  /// merge. Files newer than the local copy overwrite local; older files are
  /// ignored.
  Future<SyncResult> pull() async {
    if (_running) return SyncResult(skipped: true, reason: 'already running');
    _running = true;
    _statusController.add(const SyncStatus(syncing: true, phase: 'pulling'));
    int downloaded = 0;
    int conflicts = 0;
    try {
      final remoteFiles = await provider.list(prefix: 'notes');
      for (final file in remoteFiles) {
        if (!file.path.endsWith('.qnote.json')) continue;
        final noteId = file.path.split('/').last.replaceAll('.qnote.json', '');
        try {
          final result = await _mergeRemoteNote(noteId, file);
          if (result.downloaded) downloaded++;
          if (result.conflict) conflicts++;
        } catch (e) {
          _statusController.add(SyncStatus(
            syncing: false,
            phase: 'pull',
            error: e.toString(),
          ));
          break;
        }
      }
      _statusController.add(SyncStatus(syncing: false, phase: 'pulled'));
      return SyncResult(downloaded: downloaded, conflicts: conflicts);
    } finally {
      _running = false;
    }
  }

  /// Convenience: push then pull.
  Future<SyncResult> sync() async {
    final push = await pushDirty();
    if (push.failed > 0) return push;
    return pull();
  }

  Future<void> _uploadNote(NoteRow note) async {
    final pages = await pagesDao.listForNote(note.id);
    final payload = NotePayload(
      version: NotePayload.currentVersion,
      id: note.id,
      folderId: note.folderId,
      kind: note.kind,
      title: note.title,
      contentJson: note.contentJson,
      preview: note.preview,
      color: note.color,
      pinned: note.pinned,
      archived: note.archived,
      trashed: note.trashed,
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
      drawingPages: pages.map(DrawingPagePayload.fromRow).toList(),
    );
    final bytes = utf8.encode(payload.encode());
    final remotePath = 'notes/${note.id}.qnote.json';
    final result = await provider.upload(
      path: remotePath,
      bytes: bytes,
      expectedEtag: note.cloudEtag,
    );
    await notesDao.markSynced(
      id: note.id,
      etag: result.etag,
      provider: _providerName(),
      syncedAt: DateTime.now(),
    );
  }

  Future<({bool downloaded, bool conflict})> _mergeRemoteNote(
    String noteId,
    CloudFileMetadata remote,
  ) async {
    final local = await notesDao.findById(noteId);
    if (local == null) {
      final res = await provider.download('notes/$noteId.qnote.json');
      if (res == null) return (downloaded: false, conflict: false);
      final payload = NotePayload.decode(utf8.decode(res.bytes));
      await _applyPayload(payload, res.metadata);
      return (downloaded: true, conflict: false);
    }
    // Decision tree:
    //   1) Remote newer than local AND local is clean → safely overwrite.
    //   2) Remote newer than local AND local is dirty → last-write-wins
    //      (we still trust the remote as authoritative because the user's
    //      device-2 edits are typically the ones they want to keep).
    //   3) Local newer than or equal to remote AND local is dirty → keep
    //      local; the next pushDirty will re-upload.
    //   4) Local newer than or equal to remote AND local is clean →
    //      reconcile by re-applying remote (heals any torn writes, e.g.
    //      pages dropped by a previous partial upload).
    final remoteNewer =
        remote.modifiedAt.isAfter(local.updatedAt.add(const Duration(seconds: 1)));
    if (remoteNewer) {
      final res = await provider.download('notes/$noteId.qnote.json');
      if (res == null) return (downloaded: false, conflict: false);
      final payload = NotePayload.decode(utf8.decode(res.bytes));
      await _applyPayload(payload, res.metadata);
      return (
        downloaded: true,
        conflict: local.isDirty, // remote overwrote local edits
      );
    }
    if (!local.isDirty) {
      // Heel-pull: re-apply remote to repair torn state.
      final res = await provider.download('notes/$noteId.qnote.json');
      if (res == null) return (downloaded: false, conflict: false);
      final payload = NotePayload.decode(utf8.decode(res.bytes));
      await _applyPayload(payload, res.metadata);
      return (downloaded: true, conflict: false);
    }
    return (downloaded: false, conflict: false);
  }

  Future<void> _applyPayload(NotePayload payload, CloudFileMetadata meta) async {
    await notesDao.upsert(NotesCompanion.insert(
      id: payload.id,
      folderId: Value(payload.folderId),
      kind: Value(payload.kind),
      title: Value(payload.title),
      contentJson: Value(payload.contentJson),
      preview: Value(payload.preview),
      color: Value(payload.color),
      pinned: Value(payload.pinned),
      archived: Value(payload.archived),
      trashed: Value(payload.trashed),
      createdAt: payload.createdAt,
      updatedAt: payload.updatedAt,
      cloudEtag: Value(meta.etag),
      cloudProvider: Value(_providerName()),
      cloudSyncedAt: Value(DateTime.now()),
      isDirty: const Value(false),
    ));
    // Replace drawing pages wholesale — simpler than diffing.
    final existing = await pagesDao.listForNote(payload.id);
    for (final p in existing) {
      await pagesDao.deleteById(p.id);
    }
    for (final p in payload.drawingPages) {
      await pagesDao.upsert(DrawingPagesCompanion.insert(
        id: p.id,
        noteId: p.noteId,
        pageIndex: p.pageIndex,
        strokes: Value(p.strokes),
        color: Value(p.color),
        createdAt: p.createdAt,
        updatedAt: p.updatedAt,
      ));
    }
  }

  String _providerName() {
    switch (provider.id) {
      case CloudProviderId.oneDrive:
        return 'onedrive';
      case CloudProviderId.icloud:
        return 'icloud';
    }
  }

  @visibleForTesting
  bool get isBusy => _running;
}

class SyncStatus {
  const SyncStatus({
    required this.syncing,
    required this.phase,
    this.error,
  });
  final bool syncing;
  final String phase;
  final String? error;
}

class SyncResult {
  const SyncResult({
    this.uploaded = 0,
    this.failed = 0,
    this.downloaded = 0,
    this.conflicts = 0,
    this.skipped = false,
    this.reason,
  });
  final int uploaded;
  final int failed;
  final int downloaded;
  final int conflicts;
  final bool skipped;
  final String? reason;

  int get totalChanges => uploaded + downloaded;
  bool get hasErrors => failed > 0 || conflicts > 0;
}