import 'dart:ui';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:dart_earcut/dart_earcut.dart';
import 'geometry_model_ui.dart';
import 'simplify.dart';

typedef TilePoint = Offset;

extension Point on TilePoint {
  double get x => dx;
  double get y => dy;

  double distanceSq(TilePoint rhs) {
    final double dx = this.dx - rhs.dx;
    final double dy = this.dy - rhs.dy;
    return dx * dx + dy * dy;
  }
}

typedef Bounds = Rect;

extension BoundsExtension on Bounds {
  /// Tests whether [another] is inside or along the edges of `this`.
  bool containsPoint(TilePoint another) {
    return another.x >= left &&
        another.x <= right &&
        another.y >= top &&
        another.y <= bottom;
  }

  bool intersects(Bounds other) {
    return (left <= other.right &&
        other.left <= right &&
        top <= other.bottom &&
        other.top <= bottom);
  }
}

class TileLine {
  final List<TilePoint> points;
  Bounds? _bounds;

  TileLine(this.points);

  Bounds bounds() {
    var bounds = _bounds;
    if (bounds == null) {
      var minX = double.infinity;
      var maxX = double.negativeInfinity;
      var minY = double.infinity;
      var maxY = double.negativeInfinity;
      for (final point in points) {
        minX = min(minX, point.x);
        maxX = max(maxX, point.x);
        minY = min(minY, point.y);
        maxY = max(maxY, point.y);
      }
      bounds = Bounds.fromPoints(TilePoint(minX, minY), TilePoint(maxX, maxY));
      _bounds = bounds;
    }
    return bounds;
  }

  @override
  bool operator ==(Object other) =>
      other is TileLine && _equality.equals(points, other.points);

  @override
  int get hashCode => _equality.hash(points);

  @override
  String toString() => "TileLine($points)";
}

class TilePolygon {
  final List<TileLine> rings;
  List<Offset>? _trianglePoints;
  List<double>? _points;

  TilePolygon(this.rings);

  Bounds bounds() => rings.first.bounds();

  List<int> _getTriangles(List<Offset> points) {
    final ps = List<double>.generate(points.length * 2, (index) {
      if (index.isEven) {
        return points[index ~/ 2].dx;
      }
      return points[index ~/ 2].dy;
    });

    return Earcut.triangulateRaw(ps);
  }

  List<double> getEarcutTriangles() {
    return _points ??= () {
      final trianglePoints = <double>[];
      for (final ring in rings) {
        final points = ring.points;
        if (points.length < 3) {
          continue;
        }

        final triangles = _getTriangles(points);

        final len = triangles.length;
        for (int i = 0; i < len; ++i) {
          final p = points[triangles[i]];
          trianglePoints.add(p.dx);
          trianglePoints.add(p.dy);
        }
      }
      return trianglePoints;
    }();
  }

  List<Offset> get trianglePoints {
    return _trianglePoints ??= () {
      final trianglePoints = <Offset>[];
      for (final ring in rings) {
        final points = simplify
            ? simplifyPoints(
                points: ring.points,
                tolerance: tolerance,
                highQuality: true,
              )
            : ring.points;
        if (points.length < 3) {
          continue;
        }

        final triangles = _getTriangles(points);

        final len = triangles.length;
        for (int i = 0; i < len; ++i) {
          trianglePoints.add(points[triangles[i]]);
        }
      }
      return trianglePoints;
    }();
  }

  @override
  bool operator ==(Object other) =>
      other is TilePolygon && _equality.equals(rings, other.rings);

  @override
  int get hashCode => _equality.hash(rings);

  @override
  String toString() => "TilePolygon($rings)";
}

const _equality = ListEquality();
