// implementation based on
//   https://github.com/mourner/simplify-js/blob/master/simplify.js
// and ripped straight out of flutter_map.

import 'geometry_model.dart';

/// square distance from a point to a segment
double getSqSegDist(
  final double px,
  final double py,
  final double x0,
  final double y0,
  final double x1,
  final double y1,
) {
  double dx = x1 - x0;
  double dy = y1 - y0;
  if (dx != 0 || dy != 0) {
    final double t = ((px - x0) * dx + (py - y0) * dy) / (dx * dx + dy * dy);
    if (t > 1) {
      dx = px - x1;
      dy = py - y1;
      return dx * dx + dy * dy;
    } else if (t > 0) {
      dx = px - (x0 + dx * t);
      dy = py - (y0 + dy * t);
      return dx * dx + dy * dy;
    }
  }

  dx = px - x0;
  dy = py - y0;

  return dx * dx + dy * dy;
}

//! Might actually be more expensive than DP, which is also better
List<TilePoint> simplifyRadialDist(
  List<TilePoint> points,
  double sqTolerance,
) {
  TilePoint prevPoint = points[0];
  final List<TilePoint> newPoints = [prevPoint];
  late TilePoint point;
  for (int i = 1, len = points.length; i < len; i++) {
    point = points[i];
    if (point.distanceSq(prevPoint) > sqTolerance) {
      newPoints.add(point);
      prevPoint = point;
    }
  }
  if (prevPoint != point) {
    newPoints.add(point);
  }
  return newPoints;
}

void _simplifyDPStep(
  List<TilePoint> points,
  final int first,
  final int last,
  double sqTolerance,
  List<TilePoint> simplified,
) {
  double maxSqDist = sqTolerance;
  final p0 = points[first];
  final p1 = points[last];

  late int index;
  for (int i = first + 1; i < last; i++) {
    final p = points[i];
    final double sqDist = getSqSegDist(p.x, p.y, p0.x, p0.y, p1.x, p1.y);

    if (sqDist > maxSqDist) {
      index = i;
      maxSqDist = sqDist;
    }
  }
  if (maxSqDist > sqTolerance) {
    if (index - first > 1) {
      _simplifyDPStep(points, first, index, sqTolerance, simplified);
    }
    simplified.add(points[index]);
    if (last - index > 1) {
      _simplifyDPStep(points, index, last, sqTolerance, simplified);
    }
  }
}

/// simplification using the Ramer-Douglas-Peucker algorithm
List<TilePoint> simplifyDouglasPeucker(
  List<TilePoint> points,
  double sqTolerance,
) {
  final int last = points.length - 1;
  final List<TilePoint> simplified = [points[0]];
  _simplifyDPStep(points, 0, last, sqTolerance, simplified);
  simplified.add(points[last]);
  return simplified;
}

List<TilePoint> simplifyPoints({
  required final List<TilePoint> points,
  required double tolerance,
  required bool highQuality,
}) {
  // Don't simplify anything less than a square
  if (points.length <= 4) return points;

  final double sqTolerance = tolerance * tolerance;
  return highQuality
      ? simplifyDouglasPeucker(points, sqTolerance)
      : simplifyRadialDist(points, sqTolerance);
}
