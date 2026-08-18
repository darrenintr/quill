import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import 'database_providers.dart';

/// Streaming providers — these re-emit whenever the underlying table changes.

final allNotesProvider = StreamProvider<List<NoteRow>>((ref) {
  return ref.watch(notesDaoProvider).watchAll();
});

final notesInFolderProvider =
    StreamProvider.family<List<NoteRow>, String?>((ref, folderId) {
  return ref.watch(notesDaoProvider).watchInFolder(folderId);
});

final pinnedNotesProvider = StreamProvider<List<NoteRow>>((ref) {
  return ref.watch(notesDaoProvider).watchPinned();
});

final allFoldersProvider = StreamProvider<List<FolderRow>>((ref) {
  return ref.watch(foldersDaoProvider).watchAll();
});

final folderCountsProvider = StreamProvider<Map<String, int>>((ref) {
  return ref.watch(foldersDaoProvider).watchCounts();
});

final allTagsProvider = StreamProvider<List<TagRow>>((ref) {
  return ref.watch(tagsDaoProvider).watchAll();
});

final tagCountsProvider = StreamProvider<Map<String, int>>((ref) {
  return ref.watch(tagsDaoProvider).watchCounts();
});

final noteByIdProvider = StreamProvider.family<NoteRow?, String>((ref, id) {
  return ref.watch(notesDaoProvider).watchById(id);
});

final tagsForNoteProvider = StreamProvider.family<List<TagRow>, String>(
  (ref, id) {
    return ref.watch(notesDaoProvider).watchTagsForNote(id);
  },
);

final searchProvider =
    StreamProvider.family<List<NoteRow>, String>((ref, query) {
  return ref.watch(notesDaoProvider).search(query);
});

final notesForTagProvider =
    StreamProvider.family<List<NoteRow>, String>((ref, tagId) {
  return ref.watch(tagsDaoProvider).watchNotesForTag(tagId);
});