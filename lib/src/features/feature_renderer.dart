import '../context.dart';
import '../logger.dart';
import '../model/tile_model.dart';
import '../themes/style.dart';
import '../themes/theme.dart';
import 'fill_renderer.dart';
import 'line_renderer.dart';
import 'symbol_line_renderer.dart';
import 'symbol_point_renderer.dart';

abstract class FeatureRenderer {
  void render(
    Context context,
    ThemeLayerType layerType,
    Style style,
    TileLayer layer,
    TileFeature feature,
    bool forceFlush,
  );
}

class FeatureDispatcher {
  final Logger logger;

  final FillRenderer fillRenderer;
  final FillRenderer fillExtrusionRenderer;
  final LineRenderer lineRenderer;
  final SymbolPointRenderer symbolPointRenderer;
  final SymbolLineRenderer symbolLineRenderer;

  FeatureDispatcher(this.logger)
      : fillRenderer = FillRenderer(logger),
        fillExtrusionRenderer = FillRenderer(logger),
        lineRenderer = LineRenderer(logger),
        symbolPointRenderer = SymbolPointRenderer(logger),
        symbolLineRenderer = SymbolLineRenderer(logger);

  FeatureRenderer? getFeatureRenderer(
    ThemeLayerType layerType,
    TileFeature feature,
  ) =>
      switch (layerType) {
        ThemeLayerType.fill => fillRenderer,
        ThemeLayerType.fillExtrusion => fillExtrusionRenderer,
        ThemeLayerType.line => lineRenderer,
        ThemeLayerType.symbol => switch (feature.type) {
            TileFeatureType.point => symbolPointRenderer,
            TileFeatureType.linestring => symbolLineRenderer,
            _ => null,
          },
        _ => null,
      };
}
