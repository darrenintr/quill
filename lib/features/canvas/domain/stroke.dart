import 'dart:convert';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import 'brush.dart';

/// One sampled point inside a stroke. Stored alongside the stroke so we can
/// replay it for smoothing / pressure without losing fidelity.
@immutable
class StrokePoint {
  const StrokePoint({
    required this.x,
    required this.y,
    required this.pressure,
    this.tiltX = 0,
    this.tiltY = 0,
    this.timestamp = 0,
  });

  final double x;
  final double y;
  final double pressure; // 0..1, default 0.5 if unknown
  final double tiltX;
  final double tiltY;
  final int timestamp; // microseconds since stroke start

  Offset get offset => Offset(x, y);

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'p': pressure,
        'tx': tiltX,
        'ty': tiltY,
        'ts': timestamp,
      };

  static StrokePoint fromJson(Map<String, dynamic> json) => StrokePoint(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        pressure: ((json['p'] as num?) ?? 0.5).toDouble(),
        tiltX: ((json['tx'] as num?) ?? 0).toDouble(),
        tiltY: ((json['ty'] as num?) ?? 0).toDouble(),
        timestamp: ((json['ts'] as num?) ?? 0).toInt(),
      );

  StrokePoint copyWith({
    double? x,
    double? y,
    double? pressure,
    double? tiltX,
    double? tiltY,
    int? timestamp,
  }) =>
      StrokePoint(
        x: x ?? this.x,
        y: y ?? this.y,
        pressure: pressure ?? this.pressure,
        tiltX: tiltX ?? this.tiltX,
        tiltY: tiltY ?? this.tiltY,
        timestamp: timestamp ?? this.timestamp,
      );
}

/// A single pen stroke. Stored as a sequence of points plus the brush
/// settings at the time of drawing. Serializing the brush inside the stroke
/// means re-opening an old note preserves the exact look.
@immutable
class Stroke {
  Stroke({
    required this.brush,
    required this.points,
    DateTime? createdAt,
    String? id,
  })  : id = id ?? _newId(),
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final Brush brush;
  final List<StrokePoint> points;
  final DateTime createdAt;

  static int _nextId = 0;
  static String _newId() {
    _nextId += 1;
    return 's$_nextId';
  }

  Stroke copyWith({Brush? brush, List<StrokePoint>? points}) => Stroke(
        brush: brush ?? this.brush,
        points: points ?? this.points,
        createdAt: createdAt,
        id: id,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'brush': brush.toJson(),
        'points': points.map((p) => p.toJson()).toList(),
      };

  static Stroke fromJson(Map<String, dynamic> json) => Stroke(
        id: json['id'] as String?,
        brush: Brush.fromJson(json['brush'] as Map<String, dynamic>),
        points: (json['points'] as List)
            .map((p) => StrokePoint.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
}

/// Convenience list serialization for an entire page.
String strokesToJson(List<Stroke> strokes) {
  final list = strokes.map((s) => s.toJson()).toList();
  return jsonEncode(list);
}

List<Stroke> strokesFromJson(String json) {
  if (json.isEmpty || json == '[]') return [];
  try {
    final list = jsonDecode(json) as List;
    return list
        .map((m) => Stroke.fromJson(m as Map<String, dynamic>))
        .toList(growable: true);
  } catch (_) {
    return [];
  }
}