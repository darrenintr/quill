import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quill/features/canvas/domain/brush.dart';
import 'package:quill/features/canvas/domain/stroke.dart';

void main() {
  group('Brush', () {
    test('round-trips through JSON', () {
      const original = Brush(
        kind: BrushKind.highlighter,
        color: Color(0xFF1E5128),
        size: 12,
        opacity: 0.4,
      );
      final json = original.toJson();
      final restored = Brush.fromJson(json);
      expect(restored.kind, BrushKind.highlighter);
      expect(restored.color.toARGB32(), 0xFF1E5128);
      expect(restored.size, 12);
      expect(restored.opacity, 0.4);
    });

    test('toStrokeOptions changes per brush kind', () {
      const pen = Brush(kind: BrushKind.pen, color: Color(0xFF000000), size: 4, opacity: 1);
      const pencil = Brush(kind: BrushKind.pencil, color: Color(0xFF000000), size: 4, opacity: 1);
      const hi = Brush(kind: BrushKind.highlighter, color: Color(0xFFFFFF00), size: 4, opacity: 1);

      expect(pen.toStrokeOptions()['thinning'], 0.55);
      expect(pencil.toStrokeOptions()['thinning'], 0.25);
      expect(hi.toStrokeOptions()['size'], 4 * 1.6);
    });
  });

  group('Stroke', () {
    test('serializes a list of strokes losslessly', () {
      const brush = Brush(kind: BrushKind.pen, color: Color(0xFF000000), size: 4, opacity: 1);
      final strokes = [
        Stroke(
          brush: brush,
          points: const [
            StrokePoint(x: 0, y: 0, pressure: 0.5),
            StrokePoint(x: 10, y: 10, pressure: 0.7),
            StrokePoint(x: 20, y: 20, pressure: 0.3),
          ],
        ),
      ];
      final encoded = strokesToJson(strokes);
      expect(encoded.isNotEmpty, true);
      final decoded = strokesFromJson(encoded);
      expect(decoded.length, 1);
      expect(decoded.first.points.length, 3);
      expect(decoded.first.points.first.x, 0);
      expect(decoded.first.points.last.y, 20);
    });

    test('strokesFromJson handles empty / invalid input', () {
      expect(strokesFromJson(''), isEmpty);
      expect(strokesFromJson('[]'), isEmpty);
      expect(strokesFromJson('not-json'), isEmpty);
    });

    test('stroke copyWith replaces points without losing brush', () {
      const brush = Brush(kind: BrushKind.pencil, color: Color(0xFF000000), size: 4, opacity: 1);
      final stroke = Stroke(brush: brush, points: const [StrokePoint(x: 0, y: 0, pressure: 0.5)]);
      final next = stroke.copyWith(points: const [
        StrokePoint(x: 5, y: 5, pressure: 0.7),
        StrokePoint(x: 10, y: 10, pressure: 0.8),
      ]);
      expect(next.brush.kind, BrushKind.pencil);
      expect(next.points.length, 2);
    });
  });
}