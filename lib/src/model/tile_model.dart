import 'dart:typed_data';
import 'dart:ui';

import 'geometry_model.dart';
import 'geometry_model_ui.dart';

class Tile {
  final List<TileLayer> layers;

  Tile({required this.layers});
}

class TileLayer {
  final String name;
  final int extent;
  final List<TileFeature> features;

  TileLayer({required this.name, required this.extent, required this.features});
}

class BoundedPath {
  final Path path;
  Rect? _bounds;
  List<PathMetric>? _pathMetrics;

  BoundedPath(this.path);

  Rect get bounds {
    var bounds = _bounds;
    if (bounds == null) {
      bounds = path.getBounds();
      _bounds = bounds;
    }
    return bounds;
  }

  List<PathMetric> get pathMetrics {
    var pathMetrics = _pathMetrics;
    if (pathMetrics == null) {
      pathMetrics = path.computeMetrics().toList(growable: false);
      _pathMetrics = pathMetrics;
    }
    return pathMetrics;
  }
}

class TileFeature {
  final TileFeatureType type;
  final Map<String, dynamic> properties;

  // Inputs.
  final List<TilePoint> _modelPoints;
  final List<TileLine> _modelLines;
  final List<TilePolygon> _modelPolygons;

  // Cached values.
  List<BoundedPath>? _paths;
  BoundedPath? _compoundPath;

  TileFeature({
    required this.type,
    required this.properties,
    required List<TilePoint>? points,
    required List<TileLine>? lines,
    required List<TilePolygon>? polygons,
  })  : _modelPoints = points ?? const [],
        _modelLines = lines ?? const [],
        _modelPolygons = polygons ?? const [];

  List<TilePoint> get points {
    assert(type == TileFeatureType.point, 'Feature does not have points');
    return _modelPoints;
  }

  bool get hasPaths =>
      type == TileFeatureType.linestring || type == TileFeatureType.polygon;

  bool get hasPoints => type == TileFeatureType.point;

  BoundedPath get compoundPath {
    return _compoundPath ??= () {
      final paths = this.paths;
      if (paths.length == 1) {
        return paths.first;
      } else {
        final linesPath = Path();
        for (final line in paths) {
          linesPath.addPath(line.path, Offset.zero);
        }
        return BoundedPath(linesPath);
      }
    }();
  }

  List<BoundedPath> get paths {
    assert(
        type != TileFeatureType.point, 'Cannot get paths from a point feature');

    return _paths ??= () {
      return switch (type) {
        TileFeatureType.linestring => _modelLines
            .where((e) => e.points.length > 1)
            .map((e) => BoundedPath(createLine(e)))
            .toList(growable: false),
        TileFeatureType.polygon => _modelPolygons
            .where((e) => e.rings.first.points.length >= 3)
            .map((e) => BoundedPath(createPolygon(e)))
            .toList(growable: false),
        _ => throw Exception('type mismatch'),
      };
    }();
  }

  void pushTrianglePoints(Bounds? clip, List<Offset> trianglePoints) {
    for (final polygon in _modelPolygons) {
      if (clip?.overlaps(polygon.bounds()) ?? true) {
        trianglePoints.addAll(polygon.trianglePoints);
      }
    }
  }

  void pushTrianglePointsDouble(Bounds? clip, List<double> trianglePoints) {
    for (final polygon in _modelPolygons) {
      if (clip?.overlaps(polygon.bounds()) ?? true) {
        trianglePoints.addAll(polygon.getEarcutTriangles());
      }
    }
  }

  Vertices getVertices(Bounds clip) {
    final trianglePoints = <Offset>[];
    pushTrianglePoints(clip, trianglePoints);
    return toVertices(trianglePoints);
  }
}

Vertices toVerticesDouble(List<double> trianglePoints) =>
    Vertices.raw(VertexMode.triangles, Float32List.fromList(trianglePoints));

Vertices toVertices(List<Offset> trianglePoints) {
  final points = Float32List(trianglePoints.length * 2);
  for (int i = 0; i < trianglePoints.length; ++i) {
    points[i * 2] = trianglePoints[i].dx;
    points[i * 2 + 1] = trianglePoints[i].dy;
  }
  return Vertices.raw(VertexMode.triangles, points);
}

enum TileFeatureType { point, linestring, polygon, background, none }
