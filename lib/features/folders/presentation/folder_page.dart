import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../app/router.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../data/database/app_database.dart';
import '../../home/presentation/note_card.dart';

class FolderPage extends ConsumerWidget {
  const FolderPage({required this.folderId, super.key});
  final String folderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folderAsync = ref.watch(allFoldersProvider);
    final notesAsync = ref.watch(notesInFolderProvider(folderId));
    final colorScheme = Theme.of(context).colorScheme;

    final folder = folderAsync
        .asData?.value
        .where((f) => f.id == folderId)
        .cast<FolderRow?>()
        .firstWhere((_) => true, orElse: () => null);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: Color(folder?.color ?? 0xFF6750A4)
                  .withValues(alpha: 0.18),
              foregroundColor: Color(folder?.color ?? 0xFF6750A4),
              child: Icon(
                IconData(folder?.iconCodePoint ?? 0xe2c7,
                    fontFamily: 'MaterialIcons'),
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Text(folder?.name ?? 'Folder'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Rename',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _renameFolder(context, ref, folder),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: const Text('New note'),
        onPressed: () => _createNote(context, ref),
      ),
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (notes) {
          if (notes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.folder_open_outlined,
                        size: 72, color: colorScheme.outline),
                    const SizedBox(height: 12),
                    Text('No notes in this folder yet',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: notes.length,
            itemBuilder: (context, i) {
              final note = notes[i];
              return NoteCard(
                note: note,
                onTap: () => context.push(AppRoutes.editorById(note.id)),
                onLongPress: () => _showActions(context, ref, note),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _createNote(BuildContext context, WidgetRef ref) async {
    final dao = ref.read(notesDaoProvider);
    final id = const Uuid().v4();
    final now = DateTime.now();
    await dao.upsert(NotesCompanion.insert(
      id: id,
      folderId: Value(folderId),
      title: const Value('Untitled'),
      createdAt: now,
      updatedAt: now,
    ));
    if (context.mounted) context.push(AppRoutes.editorById(id));
  }

  Future<void> _renameFolder(
      BuildContext context, WidgetRef ref, FolderRow? f) async {
    if (f == null) return;
    final controller = TextEditingController(text: f.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      await ref.read(foldersDaoProvider).rename(f.id, newName);
    }
  }

  void _showActions(BuildContext context, WidgetRef ref, NoteRow note) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(
                note.pinned
                    ? Icons.push_pin_rounded
                    : Icons.push_pin_outlined,
              ),
              title: Text(note.pinned ? 'Unpin' : 'Pin'),
              onTap: () async {
                await ref
                    .read(notesDaoProvider)
                    .setPinned(note.id, !note.pinned);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: Text(note.archived ? 'Unarchive' : 'Archive'),
              onTap: () async {
                await ref
                    .read(notesDaoProvider)
                    .setArchived(note.id, !note.archived);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Move to trash'),
              onTap: () async {
                await ref.read(notesDaoProvider).setTrashed(note.id, true);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}