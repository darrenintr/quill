import 'package:flutter/material.dart';

import '../domain/brush.dart';

/// A floating, draggable brush palette. Lives above the canvas; selecting a
/// different brush / color emits a callback that the canvas listens to.
class BrushPicker extends StatelessWidget {
  const BrushPicker({
    required this.brush,
    required this.onBrushChanged,
    required this.onUndo,
    required this.onClear,
    this.onToggleGrid,
    this.gridEnabled = false,
    super.key,
  });

  final Brush brush;
  final ValueChanged<Brush> onBrushChanged;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final VoidCallback? onToggleGrid;
  final bool gridEnabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      elevation: 6,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final kind in BrushKind.values)
              _BrushButton(
                kind: kind,
                selected: brush.kind == kind,
                onTap: () => onBrushChanged(brush.copyWith(kind: kind)),
              ),
            const SizedBox(width: 8),
            Container(width: 1, height: 32, color: colorScheme.outlineVariant),
            const SizedBox(width: 8),
            for (final color in BrushPalette.colors)
              _ColorSwatch(
                color: color,
                selected: brush.color.toARGB32() == color.toARGB32(),
                onTap: () => onBrushChanged(brush.copyWith(color: color)),
              ),
            const SizedBox(width: 8),
            Container(width: 1, height: 32, color: colorScheme.outlineVariant),
            const SizedBox(width: 8),
            _SizeSlider(
              size: brush.size,
              onChanged: (s) => onBrushChanged(brush.copyWith(size: s)),
            ),
            if (onToggleGrid != null) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Toggle grid',
                icon: Icon(
                  gridEnabled
                      ? Icons.grid_on_rounded
                      : Icons.grid_off_rounded,
                ),
                onPressed: onToggleGrid,
              ),
            ],
            IconButton(
              tooltip: 'Undo last stroke',
              icon: const Icon(Icons.undo_rounded),
              onPressed: onUndo,
            ),
            IconButton(
              tooltip: 'Clear page',
              icon: const Icon(Icons.layers_clear_rounded),
              onPressed: onClear,
            ),
          ],
        ),
      ),
    );
  }
}

class _BrushButton extends StatelessWidget {
  const _BrushButton({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final BrushKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: kind.name,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(_iconFor(kind), size: 22),
        ),
      ),
    );
  }

  IconData _iconFor(BrushKind kind) => switch (kind) {
        BrushKind.pen => Icons.edit_rounded,
        BrushKind.pencil => Icons.draw_rounded,
        BrushKind.highlighter => Icons.highlight_rounded,
        BrushKind.eraser => Icons.cleaning_services_rounded,
      };
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkResponse(
        onTap: onTap,
        radius: 18,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Colors.white : Colors.transparent,
              width: 3,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}

class _SizeSlider extends StatelessWidget {
  const _SizeSlider({required this.size, required this.onChanged});

  final double size; // 1..24
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: Slider(
        min: 2,
        max: 24,
        value: size.clamp(2, 24),
        onChanged: onChanged,
      ),
    );
  }
}