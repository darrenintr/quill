import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as fq;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/database_providers.dart';
import '../../../core/utils/date_formats.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/database/app_database.dart';
import '../../canvas/presentation/notebook_editor.dart';

/// Note editor. Routes to the text editor or the drawing notebook depending
/// on the note's [kind] field (default 'text').
class EditorPage extends ConsumerWidget {
  const EditorPage({required this.noteId, super.key});
  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteAsync = ref.watch(_noteByIdProvider(noteId));
    return noteAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (note) {
        if (note == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Note not found')),
          );
        }
        if (note.kind == 'drawing') {
          return _DrawingEditorScaffold(note: note);
        }
        return _TextEditorScaffold(note: note);
      },
    );
  }
}

/// Bridges a [NoteRow] lookup into a Provider so the editor rebuilds when
/// the row changes (rename, archive, etc.).
final _noteByIdProvider =
    StreamProvider.family.autoDispose<NoteRow?, String>((ref, id) {
  return ref.watch(notesDaoProvider).watchById(id);
});

// ---------------- Text editor (existing, lifted into a scaffold) ----------------

class _TextEditorScaffold extends ConsumerStatefulWidget {
  const _TextEditorScaffold({required this.note});
  final NoteRow note;

  @override
  ConsumerState<_TextEditorScaffold> createState() =>
      _TextEditorScaffoldState();
}

class _TextEditorScaffoldState extends ConsumerState<_TextEditorScaffold> {
  final _titleController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  fq.QuillController? _quill;
  Timer? _debounce;
  String _lastSavedTitle = '';
  String _lastSavedJson = '[]';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dao = ref.read(notesDaoProvider);
    final note = await dao.findById(widget.note.id);
    if (note == null || !mounted) return;
    final content = note.contentJson;
    final delta = _decodeDelta(content);
    final controller = fq.QuillController(
      document: delta ?? fq.Document(),
      selection: const TextSelection.collapsed(offset: 0),
    );
    controller.addListener(_scheduleAutosave);
    setState(() {
      _quill = controller;
      _titleController.text = note.title;
      _titleController.addListener(_scheduleAutosave);
      _lastSavedTitle = note.title;
      _lastSavedJson = content;
    });
  }

  fq.Document? _decodeDelta(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) return fq.Document.fromJson(decoded);
    } catch (_) {}
    return null;
  }

  void _scheduleAutosave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _save);
  }

  Future<void> _save() async {
    final controller = _quill;
    final note = widget.note;
    if (controller == null) return;
    final title = _titleController.text.trim().isEmpty
        ? 'Untitled'
        : _titleController.text;
    final json = jsonEncode(controller.document.toDelta().toJson());
    final preview = controller.document.toPlainText().trim().split('\n').take(3).join(' ');
    if (title == _lastSavedTitle && json == _lastSavedJson) return;
    await ref.read(notesDaoProvider).updateContent(
          id: note.id,
          title: title,
          contentJson: json,
          preview: preview.length > 240 ? preview.substring(0, 240) : preview,
        );
    _lastSavedTitle = title;
    _lastSavedJson = json;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _save();
    _quill?.removeListener(_scheduleAutosave);
    _titleController.removeListener(_scheduleAutosave);
    _quill?.dispose();
    _titleController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quill = _quill;
    if (quill == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final note = widget.note;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () async {
            await _save();
            if (context.mounted) context.pop();
          },
        ),
        title: Text(
          formatRelativeTime(note.updatedAt),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.outline,
              ),
        ),
        actions: [
          IconButton(
            tooltip: note.pinned ? 'Unpin' : 'Pin',
            icon: Icon(
              note.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            ),
            onPressed: () async {
              await ref
                  .read(notesDaoProvider)
                  .setPinned(note.id, !note.pinned);
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'trash':
                  await ref.read(notesDaoProvider).setTrashed(note.id, true);
                  if (context.mounted) context.pop();
                case 'delete':
                  await ref.read(notesDaoProvider).deletePermanently(note.id);
                  if (context.mounted) context.pop();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'trash',
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('Move to trash'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_forever_outlined),
                  title: Text('Delete forever'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.readableMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: TextField(
                    controller: _titleController,
                    textInputAction: TextInputAction.next,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Title',
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: fq.QuillEditor.basic(
                      controller: quill,
                      focusNode: _focusNode,
                      scrollController: _scrollController,
                      config: fq.QuillEditorConfig(
                        autoFocus: false,
                        placeholder: 'Start writing…',
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        expands: true,
                        customStyles: fq.DefaultStyles(
                          paragraph: fq.DefaultTextBlockStyle(
                            Theme.of(context).textTheme.bodyLarge!,
                            const fq.HorizontalSpacing(0, 0),
                            const fq.VerticalSpacing(8, 0),
                            fq.VerticalSpacing.zero,
                            null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _Toolbar(controller: quill),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.controller});
  final fq.QuillController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: fq.QuillSimpleToolbar(
          controller: controller,
          config: const fq.QuillSimpleToolbarConfig(
            multiRowsDisplay: false,
            showAlignmentButtons: false,
            showColorButton: false,
            showBackgroundColorButton: false,
            showCodeBlock: true,
            showInlineCode: true,
            showQuote: true,
            showLink: false,
            showSearchButton: false,
            showSubscript: false,
            showSuperscript: false,
            showClearFormat: true,
            showDividers: true,
            showFontFamily: false,
            showFontSize: false,
            showStrikeThrough: false,
            showUndo: true,
            showRedo: true,
            showDirection: false,
            showJustifyAlignment: false,
            showLeftAlignment: false,
            showRightAlignment: false,
            showCenterAlignment: false,
            showHeaderStyle: true,
            showListBullets: true,
            showListNumbers: true,
            showListCheck: true,
            showIndent: false,
          ),
        ),
      ),
    );
  }
}

// ---------------- Drawing editor scaffold ----------------

class _DrawingEditorScaffold extends ConsumerStatefulWidget {
  const _DrawingEditorScaffold({required this.note});
  final NoteRow note;

  @override
  ConsumerState<_DrawingEditorScaffold> createState() =>
      _DrawingEditorScaffoldState();
}

class _DrawingEditorScaffoldState
    extends ConsumerState<_DrawingEditorScaffold> {
  final _titleController = TextEditingController();
  Timer? _titleDebounce;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.note.title;
    _titleController.addListener(_onTitleChanged);
  }

  void _onTitleChanged() {
    _titleDebounce?.cancel();
    _titleDebounce = Timer(const Duration(milliseconds: 600), () async {
      await ref.read(notesDaoProvider).markDirty(widget.note.id);
    });
  }

  @override
  void dispose() {
    _titleDebounce?.cancel();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _saveTitle(String title) async {
    final cleaned = title.trim().isEmpty ? 'Untitled notebook' : title;
    await ref.read(notesDaoProvider).updateContent(
          id: widget.note.id,
          title: cleaned,
          contentJson: widget.note.contentJson,
          preview: widget.note.preview,
        );
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () async {
            await _saveTitle(_titleController.text);
            if (context.mounted) context.pop();
          },
        ),
        title: TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Notebook title',
            contentPadding: EdgeInsets.zero,
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        actions: [
          IconButton(
            tooltip: note.pinned ? 'Unpin' : 'Pin',
            icon: Icon(
              note.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            ),
            onPressed: () async {
              await ref
                  .read(notesDaoProvider)
                  .setPinned(note.id, !note.pinned);
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'trash':
                  await _saveTitle(_titleController.text);
                  await ref.read(notesDaoProvider).setTrashed(note.id, true);
                  if (context.mounted) context.pop();
                case 'delete':
                  await ref.read(notesDaoProvider).deletePermanently(note.id);
                  if (context.mounted) context.pop();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'trash',
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('Move to trash'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_forever_outlined),
                  title: Text('Delete forever'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.brush_rounded,
                      size: 16, color: colorScheme.outline),
                  const SizedBox(width: 6),
                  Text(
                    '${formatRelativeTime(note.updatedAt)} · ${note.isDirty ? "unsynced" : "synced"}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: NotebookEditor(noteId: widget.note.id),
            ),
          ],
        ),
      ),
    );
  }
}