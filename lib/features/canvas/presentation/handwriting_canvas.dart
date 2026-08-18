import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

import '../domain/brush.dart';
import '../domain/stroke.dart' as domain;

/// The headline widget: an Apple Pencil-aware drawing surface.
///
/// Architecture:
///   * The widget owns [strokes] (committed) and an in-flight [_activeStroke].
///   * Pointer events are routed through a [Listener]; stylus + touch are
///     handled differently so a resting palm never produces ink.
///   * Rendering is split: committed strokes are rendered via one
///     [CustomPainter], the in-flight stroke via another. This keeps the
///     per-frame cost low while drawing.
///   * [perfect_freehand] does the smoothing / pressure mapping; we feed it
///     raw [StrokePoint]s and draw the resulting outline as a filled [Path].
class HandwritingCanvas extends StatefulWidget {
  const HandwritingCanvas({
    required this.strokes,
    required this.brush,
    required this.onStrokesChanged,
    required this.pageSize,
    this.backgroundColor = const Color(0xFFFAFAFA),
    this.gridLines = false,
    this.enabled = true,
    super.key,
  });

  /// Committed strokes for this page. The widget re-renders when this list
  /// changes (typically when a stroke finishes).
  final List<domain.Stroke> strokes;

  /// The currently-selected brush (color, kind, size, opacity).
  final Brush brush;

  /// Called whenever the stroke list grows. Parent persists and updates state.
  final ValueChanged<List<domain.Stroke>> onStrokesChanged;

  /// Logical pixel dimensions of the page. Used for the [RepaintBoundary]
  /// export (thumbnail generation).
  final Size pageSize;

  final Color backgroundColor;
  final bool gridLines;
  final bool enabled;

  @override
  State<HandwritingCanvas> createState() => _HandwritingCanvasState();
}

class _HandwritingCanvasState extends State<HandwritingCanvas> {
  /// The stroke currently being drawn. Cleared on PointerUp.
  domain.Stroke? _activeStroke;
  List<domain.StrokePoint> _activePoints = [];

  /// Timestamp of the most recent stylus-down event. Used for palm rejection:
  /// any touch event within [kPalmRejectionWindow] of a stylus event is
  /// dropped.
  Duration? _lastStylusEvent;
  static const _kPalmRejectionWindow = Duration(milliseconds: 250);

  @override
  void initState() {
    super.initState();
    // Hidden but interactive: a transparent canvas still needs gestures.
  }

  bool _shouldAcceptPointer(PointerEvent event) {
    if (!widget.enabled) return false;
    // Stylus is always welcome.
    if (event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus) {
      _lastStylusEvent = event.timeStamp;
      return true;
    }
    // Touch: accept only if there's been no recent stylus activity.
    if (event.kind == PointerDeviceKind.touch) {
      final last = _lastStylusEvent;
      if (last != null &&
          event.timeStamp - last < _kPalmRejectionWindow) {
        return false;
      }
      return true;
    }
    return false;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!_shouldAcceptPointer(event)) return;
    final point = _toStrokePoint(event, isStart: true);
    _activeStroke = domain.Stroke(brush: widget.brush, points: [point]);
    _activePoints = [point];
    setState(() {});
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_activeStroke == null) return;
    if (!_shouldAcceptPointer(event)) return;
    final point = _toStrokePoint(event);
    _activePoints = [..._activePoints, point];
    _activeStroke = _activeStroke!.copyWith(points: _activePoints);
    setState(() {});
  }

  void _onPointerUp(PointerUpEvent event) {
    final stroke = _activeStroke;
    _activeStroke = null;
    _activePoints = [];
    if (stroke == null || stroke.points.length < 2) {
      setState(() {});
      return;
    }
    widget.onStrokesChanged([...widget.strokes, stroke]);
    setState(() {});
  }

  domain.StrokePoint _toStrokePoint(PointerEvent event, {bool isStart = false}) {
    return domain.StrokePoint(
      x: event.localPosition.dx,
      y: event.localPosition.dy,
      // PointerEvent.pressure is 0..1 on iOS for Apple Pencil.
      pressure: event.pressure > 0 ? event.pressure : 0.5,
      tiltX: event.tilt == 0 ? 0 : math.cos(event.orientation) * event.tilt,
      tiltY: event.tilt == 0 ? 0 : math.sin(event.orientation) * event.tilt,
      timestamp: isStart ? 0 : event.timeStamp.inMicroseconds,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ColoredBox(
        color: widget.backgroundColor,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: (PointerCancelEvent _) {
            _activeStroke = null;
            _activePoints = [];
            setState(() {});
          },
          child: CustomPaint(
            size: widget.pageSize,
            painter: _CommittedStrokePainter(
              strokes: widget.strokes,
              gridLines: widget.gridLines,
            ),
            foregroundPainter: _ActiveStrokePainter(
              stroke: _activeStroke,
              brush: widget.brush,
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders committed strokes. This painter is wrapped in a [RepaintBoundary]
/// so the active-stroke overlay doesn't force a re-paint of the entire
/// stroke history on every pointer-move.
class _CommittedStrokePainter extends CustomPainter {
  _CommittedStrokePainter({required this.strokes, required this.gridLines});

  final List<domain.Stroke> strokes;
  final bool gridLines;

  @override
  void paint(Canvas canvas, Size size) {
    if (gridLines) {
      _drawGrid(canvas, size);
    }
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x14000000)
      ..strokeWidth = 1;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawStroke(Canvas canvas, domain.Stroke stroke) {
    if (stroke.points.isEmpty) return;
    final outline = _strokeOutlinePoints(stroke);
    if (outline.isEmpty) return;
    final paint = Paint()
      ..color = stroke.brush.color.withValues(alpha: stroke.brush.opacity)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final path = _outlineToPath(outline);
    canvas.drawPath(path, paint);
  }

  List<Offset> _strokeOutlinePoints(domain.Stroke stroke) {
    return getStroke(
      stroke.points
          .map((p) => PointVector(p.x, p.y, p.pressure))
          .toList(),
      options: _optionsFromBrush(stroke.brush),
    );
  }

  Path _outlineToPath(List<Offset> outline) {
    final path = Path();
    if (outline.isEmpty) return path;
    path.moveTo(outline.first.dx, outline.first.dy);
    for (var i = 1; i < outline.length; i++) {
      path.lineTo(outline[i].dx, outline[i].dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(_CommittedStrokePainter old) =>
      old.strokes != strokes || old.gridLines != gridLines;
}

class _ActiveStrokePainter extends CustomPainter {
  _ActiveStrokePainter({required this.stroke, required this.brush});

  final domain.Stroke? stroke;
  final Brush brush;

  @override
  void paint(Canvas canvas, Size size) {
    final s = stroke;
    if (s == null || s.points.isEmpty) return;
    final outline = getStroke(
      s.points.map((p) => PointVector(p.x, p.y, p.pressure)).toList(),
      options: _optionsFromBrush(brush),
    );
    if (outline.isEmpty) return;
    final paint = Paint()
      ..color = brush.color.withValues(alpha: brush.opacity)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final path = Path();
    path.moveTo(outline.first.dx, outline.first.dy);
    for (var i = 1; i < outline.length; i++) {
      path.lineTo(outline[i].dx, outline[i].dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ActiveStrokePainter old) =>
      old.stroke != stroke || old.brush != brush;
}

StrokeOptions _optionsFromBrush(Brush brush) {
  final m = brush.toStrokeOptions();
  return StrokeOptions(
    size: (m['size'] as num).toDouble(),
    thinning: ((m['thinning'] as num?) ?? 0.5).toDouble(),
    smoothing: ((m['smoothing'] as num?) ?? 0.5).toDouble(),
    streamline: ((m['streamline'] as num?) ?? 0.5).toDouble(),
    simulatePressure: brush.kind == BrushKind.pencil,
    isComplete: true,
  );
}

/// Captures the canvas as a PNG — used for note thumbnails. Caller is
/// responsible for layouting the canvas into the boundary.
Future<Uint8List?> captureCanvasPng(GlobalKey boundaryKey) async {
  final ctx = boundaryKey.currentContext;
  if (ctx == null) return null;
  final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;
  final image = await boundary.toImage(pixelRatio: 2.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData?.buffer.asUint8List();
}