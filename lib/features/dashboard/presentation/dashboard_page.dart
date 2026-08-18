import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../app/router.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/utils/date_formats.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/database/app_database.dart';
import '../../home/presentation/note_card.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final showTwoPane = context.showTwoPane;

    final foldersAsync = ref.watch(allFoldersProvider);
    final notesAsync = ref.watch(allNotesProvider);
    final tagsAsync = ref.watch(allTagsProvider);
    final folderCountsAsync = ref.watch(folderCountsProvider);
    final tagCountsAsync = ref.watch(tagCountsProvider);
    final pinnedAsync = ref.watch(pinnedNotesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Quill',
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search',
            onPressed: () => context.go(AppRoutes.search),
          ),
          PopupMenuButton<String>(
            tooltip: 'New',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onSelected: (value) async {
              switch (value) {
                case 'folder':
                  await _createFolder(context, ref);
                case 'tag':
                  await _createTag(context, ref);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'folder',
                child: ListTile(
                  leading: Icon(Icons.create_new_folder_outlined),
                  title: Text('New folder'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'tag',
                child: ListTile(
                  leading: Icon(Icons.label_outline_rounded),
                  title: Text('New tag'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createNote(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New note'),
      ),
      body: SafeArea(
        child: notesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (notes) {
            if (showTwoPane) {
              return _TwoPaneDashboard(
                notes: notes,
                foldersAsync: foldersAsync,
                tagsAsync: tagsAsync,
                folderCountsAsync: folderCountsAsync,
                tagCountsAsync: tagCountsAsync,
                pinnedAsync: pinnedAsync,
              );
            }
            return _SinglePaneDashboard(
              notes: notes,
              foldersAsync: foldersAsync,
              tagsAsync: tagsAsync,
              folderCountsAsync: folderCountsAsync,
              tagCountsAsync: tagCountsAsync,
              pinnedAsync: pinnedAsync,
              colorScheme: colorScheme,
            );
          },
        ),
      ),
    );
  }

  Future<void> _createNote(BuildContext context, WidgetRef ref) async {
    final dao = ref.read(notesDaoProvider);
    final id = const Uuid().v4();
    final now = DateTime.now();
    await dao.upsert(NotesCompanion.insert(
      id: id,
      title: const Value('Untitled'),
      createdAt: now,
      updatedAt: now,
    ));
    if (context.mounted) context.push(AppRoutes.editorById(id));
  }

  Future<void> _createFolder(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Folder name',
            hintText: 'e.g. Daily Notes',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(foldersDaoProvider).upsert(
            FoldersCompanion.insert(
              id: const Uuid().v4(),
              name: name,
              createdAt: DateTime.now(),
            ),
          );
    }
  }

  Future<void> _createTag(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New tag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Tag',
            hintText: 'e.g. ideas',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(tagsDaoProvider).ensure(name);
    }
  }
}

// ---------------- Single-pane (phone) ----------------

class _SinglePaneDashboard extends StatelessWidget {
  const _SinglePaneDashboard({
    required this.notes,
    required this.foldersAsync,
    required this.tagsAsync,
    required this.folderCountsAsync,
    required this.tagCountsAsync,
    required this.pinnedAsync,
    required this.colorScheme,
  });

  final List<NoteRow> notes;
  final AsyncValue<List<FolderRow>> foldersAsync;
  final AsyncValue<List<TagRow>> tagsAsync;
  final AsyncValue<Map<String, int>> folderCountsAsync;
  final AsyncValue<Map<String, int>> tagCountsAsync;
  final AsyncValue<List<NoteRow>> pinnedAsync;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final counts = folderCountsAsync.asData?.value ?? const {};
    final folders = foldersAsync.asData?.value ?? const [];
    final tags = tagsAsync.asData?.value ?? const [];

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatLongDate(DateTime.now()),
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'What\'s on your mind?',
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (folders.isNotEmpty) ...[
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
            sliver: SliverToBoxAdapter(child: _SectionTitle('Folders')),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid.builder(
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.2,
              ),
              itemCount: folders.length,
              itemBuilder: (context, i) {
                final folder = folders[i];
                return _FolderTile(
                  folder: folder,
                  count: counts[folder.id] ?? 0,
                );
              },
            ),
          ),
        ],
        if (tags.isNotEmpty) ...[
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 4),
            sliver: SliverToBoxAdapter(child: _SectionTitle('Tags')),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in tags)
                    FilterChip(
                      label: Text(t.name),
                      avatar: CircleAvatar(
                        radius: 6,
                        backgroundColor: Color(t.color),
                      ),
                      selected: false,
                      onSelected: (_) =>
                          GoRouter.of(context).push(AppRoutes.tagById(t.id)),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 4),
          sliver: SliverToBoxAdapter(child: _SectionTitle('Recent')),
        ),
        if (notes.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyDashboard(colorScheme: colorScheme),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.builder(
              itemCount: notes.length,
              itemBuilder: (context, i) {
                final note = notes[i];
                return NoteCard(
                  note: note,
                  onTap: () => context.push(AppRoutes.editorById(note.id)),
                );
              },
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }
}

// ---------------- Two-pane (tablet/iPad/desktop) ----------------

class _TwoPaneDashboard extends StatelessWidget {
  const _TwoPaneDashboard({
    required this.notes,
    required this.foldersAsync,
    required this.tagsAsync,
    required this.folderCountsAsync,
    required this.tagCountsAsync,
    required this.pinnedAsync,
  });

  final List<NoteRow> notes;
  final AsyncValue<List<FolderRow>> foldersAsync;
  final AsyncValue<List<TagRow>> tagsAsync;
  final AsyncValue<Map<String, int>> folderCountsAsync;
  final AsyncValue<Map<String, int>> tagCountsAsync;
  final AsyncValue<List<NoteRow>> pinnedAsync;

  @override
  Widget build(BuildContext context) {
    final folders = foldersAsync.asData?.value ?? const [];
    final tags = tagsAsync.asData?.value ?? const [];
    final counts = folderCountsAsync.asData?.value ?? const {};
    final tagCounts = tagCountsAsync.asData?.value ?? const {};
    final pinned = pinnedAsync.asData?.value ?? const [];
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left pane: folders + tags + pinned
        SizedBox(
          width: 320,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 96),
            children: [
              Text('Folders',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final folder in folders)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(folder.color).withValues(alpha: 0.18),
                    foregroundColor: Color(folder.color),
                    child: Icon(
                      IconData(folder.iconCodePoint,
                          fontFamily: 'MaterialIcons'),
                      size: 20,
                    ),
                  ),
                  title: Text(folder.name),
                  trailing: Text(
                    '${counts[folder.id] ?? 0}',
                    style: TextStyle(color: colorScheme.outline),
                  ),
                  onTap: () => context.push(AppRoutes.folderById(folder.id)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Tags',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in tags)
                      ActionChip(
                        label: Text('${t.name} · ${tagCounts[t.id] ?? 0}'),
                        avatar: CircleAvatar(
                          radius: 6,
                          backgroundColor: Color(t.color),
                        ),
                        onPressed: () => context.push(AppRoutes.tagById(t.id)),
                      ),
                  ],
                ),
              ],
              if (pinned.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Pinned',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final note in pinned)
                  NoteCard(
                    note: note,
                    onTap: () => context.push(AppRoutes.editorById(note.id)),
                  ),
              ],
            ],
          ),
        ),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        // Right pane: all recent notes
        Expanded(
          child: notes.isEmpty
              ? _EmptyDashboard(colorScheme: colorScheme)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                  itemCount: notes.length,
                  itemBuilder: (context, i) {
                    final note = notes[i];
                    return NoteCard(
                      note: note,
                      onTap: () => context.push(AppRoutes.editorById(note.id)),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ---------------- Shared bits ----------------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({required this.folder, required this.count});
  final FolderRow folder;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = Color(folder.color);
    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.folderById(folder.id)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: 0.18),
                foregroundColor: color,
                child: Icon(
                  IconData(folder.iconCodePoint, fontFamily: 'MaterialIcons'),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      folder.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$count ${count == 1 ? "note" : "notes"}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard({required this.colorScheme});
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_note_rounded,
                size: 96, color: colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'Your library is empty',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the New note button to capture your first thought.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}