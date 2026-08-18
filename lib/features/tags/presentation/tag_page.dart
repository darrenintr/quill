import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/providers/repository_providers.dart';
import '../../home/presentation/note_card.dart';

class TagPage extends ConsumerWidget {
  const TagPage({required this.tagId, super.key});
  final String tagId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(allTagsProvider);
    final notesAsync = ref.watch(notesForTagProvider(tagId));

    final tag = tagsAsync.asData?.value
        .where((t) => t.id == tagId)
        .cast<dynamic>()
        .firstWhere((_) => true, orElse: () => null);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (tag != null)
              CircleAvatar(
                radius: 6,
                backgroundColor: Color(tag.color),
              ),
            const SizedBox(width: 12),
            Text(tag?.name ?? 'Tag'),
          ],
        ),
      ),
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (notes) {
          if (notes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No notes use this tag yet.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: notes.length,
            itemBuilder: (context, i) {
              final note = notes[i];
              return NoteCard(
                note: note,
                onTap: () => context.push(AppRoutes.editorById(note.id)),
              );
            },
          );
        },
      ),
    );
  }
}