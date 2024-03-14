import 'dart:ui';

import '../constants.dart';
import '../context.dart';
import '../features/tile_space_mapper.dart';
import '../model/tile_model.dart';
import '../tileset.dart';
import 'expression/expression.dart';
import 'selector.dart';
import 'style.dart';
import 'theme.dart';

class DefaultLayer extends ThemeLayer {
  final TileLayerSelector selector;
  final Style style;

  DefaultLayer(
    super.id,
    super.type, {
    required this.selector,
    required this.style,
    required super.minzoom,
    required super.maxzoom,
    required super.metadata,
  });

  @override
  void render(Context context) {
    final layers =
        selector.select(context.tileSource.tileset, context.zoom.floor());
    if (layers.isEmpty) {
      return;
    }

    final features = context.tileSource.tileset.resolver
        .resolveFeatures(selector, context.zoom.truncate())
        .toList(growable: false);

    if (features.isEmpty) {
      return;
    }

    for (final layer in layers) {
      context.tileSpaceMapper = TileSpaceMapper(
        context.canvas,
        context.tileClip,
        tileSize,
        layer.extent,
      );

      context.tileSpaceMapper.drawInTileSpace(() {
        for (int i = 0; i < features.length; ++i) {
          final layerFeature = features[i];
          final nextLayerFeature =
              i + 1 < features.length ? features[i + 1] : null;

          final renderer = context.featureRenderer.getFeatureRenderer(
            type,
            layerFeature.feature,
          );

          if (renderer == null) {
            context.logger.warn(() =>
                'layer type $type feature ${layerFeature.feature.type} is not implemented');
            continue;
          }

          // Trigger a force flush for renderers with crappy cross-feature
          // batching implementations when we know the next feature will be
          // of a different type.
          final bool forceFlush = nextLayerFeature == null ||
              nextLayerFeature.feature.type != layerFeature.feature.type;

          renderer.render(
            context,
            type,
            style,
            layerFeature.layer,
            layerFeature.feature,
            forceFlush,
          );
        }
      });
    }
  }

  @override
  String? get tileSource => selector.tileSelector.source;
}

class BackgroundLayer extends ThemeLayer {
  final Expression<Color> fillColor;

  BackgroundLayer(String id, this.fillColor, Map<String, dynamic> metadata)
      : super(id, ThemeLayerType.background,
            minzoom: 0, maxzoom: 24, metadata: metadata);

  @override
  void render(Context context) {
    context.logger.log(() => 'rendering $id');
    final color = fillColor.evaluate(EvaluationContext(
        () => {}, TileFeatureType.background, context.logger,
        zoom: context.zoom, zoomScaleFactor: 1.0, hasImage: (_) => false));
    if (color != null) {
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = color;
      context.canvas.drawRect(context.tileClip, paint);
    }
  }

  @override
  String? get tileSource => null;
}
