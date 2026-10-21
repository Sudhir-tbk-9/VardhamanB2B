import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/api/api.dart';
import 'package:vardhman_b2b/api/item_catalog_info.dart';

class CatalogController extends GetxController
    with GetSingleTickerProviderStateMixin {
  final _items = <ItemCatalogInfo>[].obs;

  /// Industry (IND / SPE) and domestic (DOM) items, split once per refresh
  /// instead of on every read; table rows look items up per line.
  final _rxIndustryItems = <ItemCatalogInfo>[].obs;

  final _rxDomesticItems = <ItemCatalogInfo>[].obs;

  /// Industry items keyed by [_itemKey] for constant time row lookups.
  var _industryItemsByKey = <String, ItemCatalogInfo>{};

  late final TabController tabController =
      TabController(length: 2, vsync: this);

  final brandEditingController = TextEditingController();
  final substrateEditingController = TextEditingController();
  final lengthEditingController = TextEditingController();
  final articleTextEditingController = TextEditingController();

  final _rxFilteredItems = RxList<ItemCatalogInfo>();

  CatalogController() {
    brandEditingController.addListener(_filterItems);
    substrateEditingController.addListener(_filterItems);
    lengthEditingController.addListener(_filterItems);
    articleTextEditingController.addListener(_filterItems);

    refreshItems();
  }

  static String _itemKey(String article, String uom) => '$article|$uom';

  Future<void> refreshItems() async {
    final items = await Api.fetchItemCatalogInfo();

    if (items.isNotEmpty) {
      final industryItems = items
          .where((item) => item.category == 'IND' || item.category == 'SPE')
          .toList();

      _industryItemsByKey = {
        // Reversed so the first match wins, as with firstWhere.
        for (final item in industryItems.reversed)
          _itemKey(item.article, item.uom): item,
      };

      _items.assignAll(items);

      _rxIndustryItems.assignAll(industryItems);

      _rxDomesticItems.assignAll(
        items.where((element) => element.category == 'DOM'),
      );
      // _filterItems();
    }
  }

  void _filterItems() {
    final brandName = brandEditingController.text.trim().toLowerCase();
    final subStrate = substrateEditingController.text.trim().toLowerCase();
    final length = lengthEditingController.text.trim().toLowerCase();
    final article = articleTextEditingController.text.trim().toLowerCase();

    final filteredItems = _items.where(
      (item) {
        return item.length.toLowerCase().contains(length) &&
            item.substrateDesc.toLowerCase().contains(subStrate) &&
            item.brandDesc.toLowerCase().contains(brandName) &&
            item.article.toLowerCase().contains(article);
      },
    ).toList();

    _rxFilteredItems.assignAll(filteredItems);
  }

  Future<void> clearFilters() async {
    brandEditingController.clear();
    substrateEditingController.clear();
    lengthEditingController.clear();
    articleTextEditingController.clear();
    _filterItems();
  }

  bool get hasFilters =>
      lengthEditingController.text.isNotEmpty ||
      substrateEditingController.text.isNotEmpty ||
      brandEditingController.text.isNotEmpty ||
      articleTextEditingController.text.isNotEmpty;

  List<ItemCatalogInfo> get industryItems => _rxIndustryItems;

  List<ItemCatalogInfo> get domesticItems => _rxDomesticItems;

  /// Industry item for [article] / [uom], or null.
  ItemCatalogInfo? industryItem({
    required String article,
    required String uom,
  }) {
    // Reading the list registers the Obx dependency, so rows rebuild once the
    // catalog loads.
    if (_rxIndustryItems.isEmpty) {
      return null;
    }

    return _industryItemsByKey[_itemKey(article, uom)];
  }
}
