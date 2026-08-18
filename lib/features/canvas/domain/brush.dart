import 'dart:ui' show Color;

/// The kinds of brush Quill supports on the canvas.
///
/// Each brush has different stroke-smoothing parameters tuned for its visual
/// character (see [strokeOptions]).
enum BrushKind {
  /// Crisp, opaque — the default writing tool.
  pen,

  /// Textured, slightly translucent — fakes graphite on paper.
  pencil,

  /// Translucent, thick — like a yellow highlighter. Adds to existing color.
  highlighter,

  /// Removes strokes that fall under the eraser path.
  eraser,
}

/// Static + dynamic parameters for a brush. Mutations to [color] / [size] /
/// [opacity] happen in real time via the brush picker UI.
class Brush {
  const Brush({
    required this.kind,
    required this.color,
    required this.size,
    required this.opacity,
  });

  final BrushKind kind;
  final Color color;
  final double size; // base diameter in logical pixels (before pressure)
  final double opacity; // 0..1

  Brush copyWith({
    BrushKind? kind,
    Color? color,
    double? size,
    double? opacity,
  }) =>
      Brush(
        kind: kind ?? this.kind,
        color: color ?? this.color,
        size: size ?? this.size,
        opacity: opacity ?? this.opacity,
      );

  /// Returns the perfect-freehand stroke options tuned for this brush.
  ///
  /// [perfect_freehand] consumes a [StrokeOptions] per stroke to control
  /// smoothing, streamline, etc. Reasonable defaults are documented inline.
  Map<String, dynamic> toStrokeOptions() {
    switch (kind) {
      case BrushKind.pen:
        return {
          'size': size,
          'thinning': 0.55,
          'smoothing': 0.5,
          'streamline': 0.5,
          'easing': 0.5,
          'start': {'tap': true, 'easing': 0.7, 'cap': true},
          'end': {'tap': true, 'easing': 0.7, 'cap': true},
        };
      case BrushKind.pencil:
        return {
          'size': size * 0.8,
          'thinning': 0.25,
          'smoothing': 0.7,
          'streamline': 0.7,
          'easing': 0.8,
        };
      case BrushKind.highlighter:
        return {
          'size': size * 1.6,
          'thinning': 0.1,
          'smoothing': 0.3,
          'streamline': 0.3,
          'easing': 0.5,
        };
      case BrushKind.eraser:
        // Eraser just renders as a wide white path — proper stroke erasure
        // is handled separately in the canvas state machine.
        return {
          'size': size * 1.5,
          'thinning': 0.0,
          'smoothing': 0.3,
          'streamline': 0.3,
        };
    }
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'color': color.toARGB32(),
        'size': size,
        'opacity': opacity,
      };

  static Brush fromJson(Map<String, dynamic> json) => Brush(
        kind: BrushKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => BrushKind.pen,
        ),
        color: Color(json['color'] as int),
        size: (json['size'] as num).toDouble(),
        opacity: (json['opacity'] as num).toDouble(),
      );
}

/// Standard 8-color palette inspired by iWork / Notes. Picked for
/// readability against white / dark backgrounds.
class BrushPalette {
  static const List<Color> colors = [
    Color(0xFF1A1A1A), // graphite
    Color(0xFF1E5128), // forest
    Color(0xFF1565C0), // ocean
    Color(0xFFC62828), // crimson
    Color(0xFFEF6C00), // tangerine
    Color(0xFFB71C1C), // red
    Color(0xFF6A1B9A), // amethyst
    Color(0xFF8B5E3C), // sepia
  ];
}