import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/api/api.dart';
import 'package:vardhman_b2b/api/item_catalog_info.dart';
import 'package:vardhman_b2b/segment/segment_controller.dart';

class CatalogController extends GetxController
    with GetSingleTickerProviderStateMixin {
  final _items = <ItemCatalogInfo>[].obs;

  /// Items of the selected segment (see [SegmentController]) and domestic
  /// (DOM) items, split once per refresh or segment change instead of on
  /// every read; table rows look items up per line.
  final _rxOrderItems = <ItemCatalogInfo>[].obs;

  final _rxDomesticItems = <ItemCatalogInfo>[].obs;

  /// Order items keyed by [_itemKey] for constant time row lookups.
  var _orderItemsByKey = <String, ItemCatalogInfo>{};

  late final TabController tabController =
      TabController(length: 2, vsync: this);

  final brandEditingController = TextEditingController();
  final substrateEditingController = TextEditingController();
  final lengthEditingController = TextEditingController();
  final articleTextEditingController = TextEditingController();

  final _rxFilteredItems = RxList<ItemCatalogInfo>();

  final _segmentController = Get.find<SegmentController>();

  CatalogController() {
    brandEditingController.addListener(_filterItems);
    substrateEditingController.addListener(_filterItems);
    lengthEditingController.addListener(_filterItems);
    articleTextEditingController.addListener(_filterItems);

    ever(_segmentController.rxSegment, (_) => _applySegment());

    refreshItems();
  }

  static String _itemKey(String article, String uom) => '$article|$uom';

  Future<void> refreshItems() async {
    final items = await Api.fetchItemCatalogInfo();

    if (items.isNotEmpty) {
      _items.assignAll(items);

      _applySegment();

      _rxDomesticItems.assignAll(
        items.where((element) => element.category == 'DOM'),
      );
      // _filterItems();
    }
  }

  /// Limits the order items to the selected segment's categories.
  void _applySegment() {
    if (_items.isEmpty) {
      logSegment('Catalog not loaded yet; it is filtered once it loads');

      return;
    }

    final segment = _segmentController.segment;

    final categories = _segmentController.categories;

    final orderItems = _items
        .where((item) => categories.contains(_categoryOf(item)))
        .toList();

    _orderItemsByKey = {
      // Reversed so the first match wins, as with firstWhere.
      for (final item in orderItems.reversed)
        _itemKey(item.article, item.uom): item,
    };

    _rxOrderItems.assignAll(orderItems);

    final itemsPerCategory = <String, int>{};

    for (final item in _items) {
      itemsPerCategory.update(
        _categoryOf(item),
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    final articles = orderItems.map((item) => item.article).toSet();

    logSegment(
      'Catalog filtered for ${segment?.title ?? 'no segment yet (All)'}: '
      'categories ${categories.join(', ')} -> ${orderItems.length} of '
      '${_items.length} items, ${articles.length} articles in the Article '
      'dropdowns. Catalog items per category: $itemsPerCategory. First '
      'articles: ${articles.take(10).join(', ')}',
    );
  }

  static String _categoryOf(ItemCatalogInfo item) =>
      item.category.trim().toUpperCase();

  /// JDE category of [article] anywhere in the catalog, or null when the
  /// catalog does not have it.
  String? categoryOfArticle(String article) {
    final key = article.trim().toUpperCase();

    final item = _items.firstWhereOrNull(
      (item) => item.article.trim().toUpperCase() == key,
    );

    return item == null ? null : _categoryOf(item);
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

  /// Items of the selected segment, offered on the order screens.
  List<ItemCatalogInfo> get orderItems => _rxOrderItems;

  List<ItemCatalogInfo> get domesticItems => _rxDomesticItems;

  /// Order item for [article] / [uom], or null.
  ItemCatalogInfo? orderItem({
    required String article,
    required String uom,
  }) {
    // Reading the list registers the Obx dependency, so rows rebuild once the
    // catalog loads.
    if (_rxOrderItems.isEmpty) {
      return null;
    }

    return _orderItemsByKey[_itemKey(article, uom)];
  }
}
