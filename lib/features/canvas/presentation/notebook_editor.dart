import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../domain/brush.dart';
import '../domain/stroke.dart';
import 'brush_picker.dart';
import 'handwriting_canvas.dart';

/// Top-level widget for a drawing / handwritten note.
///
/// State is owned locally for low-latency ink, but committed back to the
/// [DrawingPagesDao] whenever the user pauses for [autosaveDebounce].
class NotebookEditor extends ConsumerStatefulWidget {
  const NotebookEditor({
    required this.noteId,
    super.key,
  });

  final String noteId;

  @override
  ConsumerState<NotebookEditor> createState() => _NotebookEditorState();
}

class _NotebookEditorState extends ConsumerState<NotebookEditor> {
  // Per-page stroke lists, keyed by page id.
  Map<String, List<Stroke>> _strokesByPage = {};
  String? _activePageId;
  Brush _brush = const Brush(
    kind: BrushKind.pen,
    color: Color(0xFF1A1A1A),
    size: 4,
    opacity: 1,
  );
  bool _grid = false;

  Timer? _saveDebounce;
  static const _saveDelay = Duration(milliseconds: 800);

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _flushSaves();
    super.dispose();
  }

  Future<void> _flushSaves() async {
    final dao = ref.read(drawingPagesDaoProvider);
    for (final entry in _strokesByPage.entries) {
      await dao.updateStrokes(
        id: entry.key,
        strokesJson: strokesToJson(entry.value),
      );
    }
    await ref.read(notesDaoProvider).markDirty(widget.noteId);
  }

  void _scheduleSave(String pageId, List<Stroke> strokes) {
    _strokesByPage = {..._strokesByPage, pageId: strokes};
    _saveDebounce?.cancel();
    _saveDebounce = Timer(_saveDelay, _flushSaves);
  }

  Future<void> _addPage() async {
    final dao = ref.read(drawingPagesDaoProvider);
    final existing = _strokesByPage.length;
    final id = await dao.addPage(noteId: widget.noteId, pageIndex: existing);
    setState(() {
      _strokesByPage = {..._strokesByPage, id: const []};
      _activePageId = id;
    });
  }

  Future<void> _deleteActivePage() async {
    final id = _activePageId;
    if (id == null) return;
    final dao = ref.read(drawingPagesDaoProvider);
    await dao.deleteById(id);
    final remaining = Map<String, List<Stroke>>.from(_strokesByPage)
      ..remove(id);
    setState(() {
      _strokesByPage = remaining;
      _activePageId = remaining.keys.isEmpty ? null : remaining.keys.first;
    });
  }

  void _onStrokesChanged(List<Stroke> strokes) {
    final id = _activePageId;
    if (id == null) return;
    _scheduleSave(id, strokes);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pagesAsync = ref.watch(_drawingPagesStreamProvider(widget.noteId));

    return pagesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (pages) {
        // Sync loaded pages into local state once.
        if (_activePageId == null || _strokesByPage.isEmpty) {
          _activePageId ??= pages.isNotEmpty ? pages.first.id : null;
          for (final p in pages) {
            _strokesByPage.putIfAbsent(
              p.id,
              () => strokesFromJson(p.strokes),
            );
          }
        }

        if (pages.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_note_rounded,
                      size: 72, color: colorScheme.outline),
                  const SizedBox(height: 12),
                  Text(
                    'No pages yet — tap + to add one',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add first page'),
                    onPressed: _addPage,
                  ),
                ],
              ),
            ),
          );
        }

        final activeStrokes = _strokesByPage[_activePageId!] ?? const [];
        final activeIndex = pages.indexWhere((p) => p.id == _activePageId);

        return Stack(
          children: [
            // Canvas fills the available area.
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                child: HandwritingCanvas(
                  strokes: activeStrokes,
                  brush: _brush,
                  onStrokesChanged: _onStrokesChanged,
                  pageSize: const Size(double.infinity, double.infinity),
                  gridLines: _grid,
                ),
              ),
            ),
            // Brush picker pinned to the bottom.
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Center(
                child: BrushPicker(
                  brush: _brush,
                  onBrushChanged: (b) => setState(() => _brush = b),
                  onUndo: () {
                    if (activeStrokes.isEmpty) return;
                    final next = activeStrokes.sublist(0, activeStrokes.length - 1);
                    _scheduleSave(_activePageId!, next);
                    setState(() {});
                  },
                  onClear: () {
                    _scheduleSave(_activePageId!, const []);
                    setState(() {});
                  },
                  onToggleGrid: () => setState(() => _grid = !_grid),
                  gridEnabled: _grid,
                ),
              ),
            ),
            // Page indicator at the top.
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: _PageIndicator(
                  index: activeIndex,
                  total: pages.length,
                  onPrev: () {
                    if (activeIndex > 0) {
                      setState(() => _activePageId = pages[activeIndex - 1].id);
                    }
                  },
                  onNext: () {
                    if (activeIndex < pages.length - 1) {
                      setState(() => _activePageId = pages[activeIndex + 1].id);
                    }
                  },
                  onAdd: _addPage,
                  onDelete: pages.length > 1 ? _deleteActivePage : null,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Stream provider that exposes drawing pages for the active note. Lives
/// inside the file to avoid leaking it across the app.
final _drawingPagesStreamProvider =
    StreamProvider.family.autoDispose<List<dynamic>, String>((ref, noteId) {
  return ref.watch(drawingPagesDaoProvider).watchForNote(noteId);
});

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.index,
    required this.total,
    required this.onPrev,
    required this.onNext,
    required this.onAdd,
    required this.onDelete,
  });

  final int index;
  final int total;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onAdd;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 4,
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: index > 0 ? onPrev : null,
            ),
            Text(
              'Page ${index + 1} / $total',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: index < total - 1 ? onNext : null,
            ),
            const SizedBox(width: 8),
            Container(
                width: 1,
                height: 24,
                color: colorScheme.outlineVariant),
            IconButton(
              tooltip: 'Add page',
              icon: const Icon(Icons.add_rounded),
              onPressed: onAdd,
            ),
            if (onDelete != null)
              IconButton(
                tooltip: 'Delete this page',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}