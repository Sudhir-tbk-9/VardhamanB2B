import 'package:vardhman_b2b/api/api.dart';
import 'package:vardhman_b2b/api/item_catalog_info.dart';

/// Shade -> UOMs of one article (Sno 14), loaded once per article. Feeds the
/// Shade list right after the Article (K1) is picked, and the UOM (K2) once
/// the Shade (K3) is picked, on the order entry screens.
class ShadeUomLookup {
  ShadeUomLookup({this.shadeStartsWith = ''});

  /// Limits the shades, e.g. 'SWT' for DTM swatches.
  final String shadeStartsWith;

  Future<Map<String, List<String>>>? _shadeUoms;

  String? _article;

  /// [catalogItems]: the item catalog (ORCH55_GetItemCatalogInfo), giving
  /// the article's UOMs.
  Future<Map<String, List<String>>> forArticle(
    String article,
    List<ItemCatalogInfo> catalogItems,
  ) {
    if (article == _article && _shadeUoms != null) {
      return _shadeUoms!;
    }

    // Trimmed: JDE pads these fields.
    final uoms = catalogItems
        .where((item) => item.article.trim() == article)
        .map((item) => item.uom.trim())
        .where((uom) => uom.isNotEmpty)
        .toSet()
        .toList();

    _article = article;

    return _shadeUoms = Api.fetchShadeUoms(
      article: article,
      uoms: uoms,
      shadeStartsWith: shadeStartsWith,
    ).then(
      (shadeUoms) {
        // Nothing found (catalog not loaded yet, or JDE failed): try again
        // next time instead of keeping the empty result.
        if (shadeUoms.isEmpty && _article == article) {
          _shadeUoms = null;
        }

        return shadeUoms;
      },
    );
  }
}
