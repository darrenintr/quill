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

/// Note editor. The `contentJson` column stores a Quill Delta — the
/// operational model used by `flutter_quill`. We keep the controller in
/// memory and persist on a debounced flush.
class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({required this.noteId, super.key});
  final String noteId;

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  final _titleController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  fq.QuillController? _quill;
  Timer? _debounce;
  String _lastSavedTitle = '';
  String _lastSavedJson = '[]';
  NoteRow? _note;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dao = ref.read(notesDaoProvider);
    final note = await dao.findById(widget.noteId);
    if (note == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final content = note.contentJson;
    final delta = _decodeDelta(content);
    final controller = fq.QuillController(
      document: delta ?? fq.Document(),
      selection: const TextSelection.collapsed(offset: 0),
    );

    controller.addListener(_scheduleAutosave);

    if (mounted) {
      setState(() {
        _note = note;
        _titleController.text = note.title;
        _titleController.addListener(_scheduleAutosave);
        _quill = controller;
        _lastSavedTitle = note.title;
        _lastSavedJson = content;
        _loading = false;
      });
    }
  }

  fq.Document? _decodeDelta(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) {
        return fq.Document.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }

  String _encodeDelta(fq.Document doc) {
    return jsonEncode(doc.toDelta().toJson());
  }

  void _scheduleAutosave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _save);
  }

  Future<void> _save() async {
    final controller = _quill;
    final note = _note;
    if (controller == null || note == null) return;

    final title = _titleController.text.trim().isEmpty
        ? 'Untitled'
        : _titleController.text;
    final json = _encodeDelta(controller.document);
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
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_note == null || _quill == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Note not found')),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final note = _note!;
    final quill = _quill!;

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
              final updated = await ref.read(notesDaoProvider).findById(note.id);
              if (mounted && updated != null) setState(() => _note = updated);
            },
          ),
          IconButton(
            tooltip: note.archived ? 'Unarchive' : 'Archive',
            icon: Icon(
              note.archived ? Icons.archive_rounded : Icons.archive_outlined,
            ),
            onPressed: () async {
              await ref
                  .read(notesDaoProvider)
                  .setArchived(note.id, !note.archived);
              final updated = await ref.read(notesDaoProvider).findById(note.id);
              if (mounted && updated != null) setState(() => _note = updated);
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
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'trash',
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('Move to trash'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
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