import 'package:vardhman_b2b/drift/database.dart';

/// A draft line's light sources as shown in the order forms' lines table.
extension DraftLightSources on DraftTableData {
  /// "D65, U35": the first and second light source, empty ones left out.
  String get lightSourcesText => [firstLightSource, secondLightSource]
      .map((lightSource) => lightSource.trim())
      .where((lightSource) => lightSource.isNotEmpty)
      .join(', ');
}
