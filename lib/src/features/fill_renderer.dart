import 'dart:ui' as ui;

import 'package:logging/logging.dart' as log;

import '../../vector_tile_renderer.dart';
import '../context.dart';
import '../themes/expression/expression.dart';
import '../themes/style.dart';
import 'extensions.dart';
import 'feature_renderer.dart';

final batchedPath = ui.Path();
final List<double> batchedTriangles = [];
ui.Paint? prevPaint;
int batchSize = 0;

class FillRenderer extends FeatureRenderer {
  final Logger logger;
  FillRenderer(this.logger);

  @override
  void render(
    Context context,
    ThemeLayerType layerType,
    Style style,
    TileLayer layer,
    TileFeature feature,
    bool forceFlush,
  ) {
    if (!feature.hasPaths) {
      return;
    }
    if (style.fillPaint == null && style.outlinePaint == null) {
      logger
          .warn(() => 'polygon does not have a fill paint or an outline paint');
      return;
    }

    final evaluationContext = EvaluationContext(
        () => feature.properties, feature.type, logger,
        zoom: context.zoom,
        zoomScaleFactor: context.zoomScaleFactor,
        hasImage: context.hasImage);
    final fillPaint = style.fillPaint?.evaluate(evaluationContext)?.paint();
    final outlinePaint =
        style.outlinePaint?.evaluate(evaluationContext)?.paint();

    // Unfortunately, we cannot batch outlines + fill because it would change the ordering.
    if (outlinePaint != null) {
      if (fillPaint == null) {
        final path = ui.Path();
        for (final polygon in feature.paths) {
          if (!context.tileSpaceMapper.isPathWithinTileClip(polygon)) {
            continue;
          }
          path.addPath(polygon.path, const ui.Offset(0, 0));
        }
        context.canvas.drawPath(path, outlinePaint);
      } else {
        _logger.finer('Expensive outline paint');
        for (final polygon in feature.paths) {
          if (!context.tileSpaceMapper.isPathWithinTileClip(polygon)) {
            continue;
          }

          context.canvas.drawPath(polygon.path, fillPaint);
          context.canvas.drawPath(polygon.path, outlinePaint);
        }
      }
      return;
    }

    if (fillPaint == null) {
      return;
    }

    // Different draw modes
    // 0: most aggressive: batch vertices across features and drawVertices
    // 1: batch within the local set of polygons and use drawVertices
    // 2: batch paths across features but use drawPath
    // 3: batch within the local feature and use drawPaths.
    const mode = 2;
    switch (mode) {
      case 0:
        // Flush previous.
        if (prevPaint != null &&
            prevPaint != fillPaint &&
            batchedTriangles.isNotEmpty) {
          context.canvas.drawVertices(
              toVerticesDouble(batchedTriangles), ui.BlendMode.src, prevPaint!);

          //print(batchSize);
          batchSize = 0;
          batchedTriangles.clear();
          prevPaint = null;
        }

        batchSize++;
        prevPaint = fillPaint;

        final clip = context.tileSpaceMapper.tileClipInTileUnits;
        feature.pushTrianglePointsDouble(clip, batchedTriangles);

        break;
      case 1:
        final List<double> triangles = [];

        feature.pushTrianglePointsDouble(null, triangles);
        context.canvas.drawVertices(
            toVerticesDouble(triangles), ui.BlendMode.src, fillPaint);

        break;
      case 2:
        // Flush previous.
        if (prevPaint != null && prevPaint != fillPaint && batchSize > 0) {
          context.canvas.drawPath(batchedPath, prevPaint!);

          batchSize = 0;
          batchedPath.reset();
          prevPaint = null;
        }

        batchSize++;
        prevPaint = fillPaint;

        for (final polygon in feature.paths) {
          if (!context.tileSpaceMapper.isPathWithinTileClip(polygon)) {
            continue;
          }
          batchedPath.addPath(polygon.path, const ui.Offset(0, 0));
        }

        break;
      case 3:
        final path = ui.Path();

        for (final polygon in feature.paths) {
          if (!context.tileSpaceMapper.isPathWithinTileClip(polygon)) {
            continue;
          }
          path.addPath(polygon.path, const ui.Offset(0, 0));
        }

        context.canvas.drawPath(path, fillPaint);

        break;
    }

    if (mode == 1 &&
        forceFlush &&
        prevPaint != null &&
        batchedTriangles.isNotEmpty) {
      context.canvas.drawVertices(
          toVerticesDouble(batchedTriangles), ui.BlendMode.src, prevPaint!);

      batchedTriangles.clear();
      prevPaint = null;
      batchSize = 0;
    }

    if (mode == 2 && forceFlush && prevPaint != null && batchSize > 0) {
      context.canvas.drawPath(batchedPath, prevPaint!);
      batchedPath.reset();
      prevPaint = null;
      batchSize = 0;
    }

    if (forceFlush && prevPaint != null) {
      context.canvas.drawVertices(
          toVerticesDouble(batchedTriangles), ui.BlendMode.src, prevPaint!);

      batchedTriangles.clear();
      prevPaint = null;
      batchSize = 0;
    }
  }
}

final _logger = log.Logger('fill');
