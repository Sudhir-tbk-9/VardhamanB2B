import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_html/html.dart' as html;
import 'package:vardhman_b2b/drift/database.dart';
import 'package:vardhman_b2b/user/user_controller.dart';

/// Business segment the user orders in, picked once after login. Articles
/// are matched on their JDE category code (F4101.SRP1, `Category` in the
/// item catalog). Only IND, SPE and ALL (IND + SPE + DOM) are offered: DOM
/// on its own and IND + SPE were dropped after the VYTL review.
enum OrderSegment {
  industry(
    code: 'IND',
    title: 'Industry',
    icon: Icons.settings_outlined,
    categories: ['IND'],
  ),
  speciality(
    code: 'SPE',
    title: 'Speciality',
    icon: Icons.star_outline_rounded,
    categories: ['SPE'],
  ),

  /// No segment restriction: articles of every segment.
  all(
    code: 'ALL',
    title: 'All Segments',
    icon: Icons.layers_outlined,
    categories: ['IND', 'SPE', 'DOM'],
  );

  final String code;
  final String title;
  final IconData icon;

  /// JDE category codes (F4101.SRP1) of the articles offered.
  final List<String> categories;

  const OrderSegment({
    required this.code,
    required this.title,
    required this.icon,
    required this.categories,
  });

  bool includesCategory(String category) =>
      categories.contains(category.trim().toUpperCase());

  static OrderSegment? byName(String? name) =>
      OrderSegment.values.firstWhereOrNull((segment) => segment.name == name);
}

/// An order in progress: draft lines saved but not yet submitted.
class DraftOrder {
  /// DraftTable order type: BK, DT or LD (Labdip and Sampling both).
  final String orderType;

  final int orderNumber;

  final int lineCount;

  const DraftOrder({
    required this.orderType,
    required this.orderNumber,
    required this.lineCount,
  });

  String get typeName => switch (orderType) {
        'BK' => 'Bulk',
        'DT' => 'DTM',
        'LD' => 'Labdip / Sampling',
        _ => orderType,
      };

  /// The tab whose list shows this draft. LD drafts are listed on both
  /// Labdip and Sampling; Labdip is named.
  String get tabName => switch (orderType) {
        'BK' => 'Bulk',
        'DT' => 'DTM',
        'LD' => 'Labdip',
        _ => orderType,
      };

  /// URL of [tabName]'s tab (see homeTabPaths).
  String? get tabPath => switch (orderType) {
        'BK' => '/bulk',
        'DT' => '/dtm',
        'LD' => '/labdip',
        _ => null,
      };

  @override
  String toString() =>
      '$typeName draft #$orderNumber ($lineCount line${lineCount == 1 ? '' : 's'})';
}

typedef DraftOrdersLoader = Future<List<DraftOrder>> Function();

typedef DraftOrderOpener = Future<void> Function(DraftOrder draftOrder);

/// Console log of the segment flow, tagged `[SEGMENT]` so it can be
/// filtered in the browser console (debugPrint, so release builds log too).
void logSegment(String message) => debugPrint('[SEGMENT] $message');

/// The segment of the logged in user. Kept in the tab's sessionStorage, like
/// the login itself (see LoginController), so a page refresh keeps it and
/// logging out forgets it.
class SegmentController extends GetxController {
  static const _storageKey = 'orderSegment';

  /// localStorage key prefix of the segment the drafts were made in, per
  /// customer (sold-to). Drafts stay in this browser's database past a
  /// logout, so their segment has to as well: the next login is then
  /// locked to it while they are not submitted or deleted.
  static const _draftSegmentKey = 'draftSegment';

  /// Null until the user picks one in the segment dialog.
  final rxSegment = Rxn<OrderSegment>();

  /// Whether the segment dialog is on screen, so it is not opened twice.
  bool isDialogOpen = false;

  final DraftOrdersLoader _draftOrdersLoader;

  /// Replaces openDraftOrder (segment dialog lock warning), for tests.
  final DraftOrderOpener? draftOrderOpener;

  final String Function() _soldToReader;

  /// [draftOrdersLoader] replaces the DraftTable read and [soldToReader]
  /// the logged in customer's sold-to, for tests.
  SegmentController({
    DraftOrdersLoader? draftOrdersLoader,
    this.draftOrderOpener,
    String Function()? soldToReader,
  })  : _draftOrdersLoader = draftOrdersLoader ?? _loadDraftOrders,
        _soldToReader = soldToReader ?? _readSoldTo {
    rxSegment.value = OrderSegment.byName(_readStorage());

    if (rxSegment.value == null) {
      logSegment('No segment yet for this login: the selection dialog '
          'will be shown');
    } else {
      logSegment('Restored ${_describe(rxSegment.value!)} after page refresh');
    }
  }

  OrderSegment? get segment => rxSegment.value;

  bool get hasSegment => rxSegment.value != null;

  /// JDE category codes the order screens are limited to. Before a segment
  /// is picked, those of [OrderSegment.all].
  List<String> get categories =>
      (rxSegment.value ?? OrderSegment.all).categories;

  void select(OrderSegment segment) {
    final previous = rxSegment.value;

    rxSegment.value = segment;

    _writeStorage(segment.name);

    _writeDraftSegment(segment);

    logSegment(
      'Selected ${_describe(segment)}'
      '${previous == null ? '' : ' (was ${previous.title})'}. Article '
      'dropdowns, shade / UOM lookups and Excel upload now use only '
      'these categories',
    );
  }

  /// The customer's orders with lines not yet submitted. While there are
  /// any the segment cannot be changed, so an order never mixes articles
  /// of two segments.
  Future<List<DraftOrder>> draftOrders() async {
    try {
      final draftOrders = await _draftOrdersLoader();

      logSegment(draftOrders.isEmpty
          ? 'No order lines in progress: segment can be changed'
          : 'Segment switch locked by ${draftOrders.length} order(s) in '
              'progress: ${draftOrders.join(', ')}');

      return draftOrders;
    } catch (e) {
      logSegment('Could not check order lines in progress: $e');

      return const [];
    }
  }

  static Future<List<DraftOrder>> _loadDraftOrders() async {
    final soldTo = Get.find<UserController>(tag: 'userController')
        .rxUserDetail
        .value
        .soldToNumber;

    final draftLines = await Get.find<Database>()
        .managers
        .draftTable
        .filter((f) => f.soldTo.equals(soldTo))
        .get();

    final lineCounts = <(String, int), int>{};

    for (final line in draftLines) {
      lineCounts.update(
        (line.orderType, line.orderNumber),
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    return [
      for (final MapEntry(key: (orderType, orderNumber), value: lineCount)
          in lineCounts.entries)
        DraftOrder(
          orderType: orderType,
          orderNumber: orderNumber,
          lineCount: lineCount,
        ),
    ];
  }

  /// Segment the customer's drafts in this browser were made in, or null
  /// when not known (e.g. drafts saved before it was kept).
  OrderSegment? get draftSegment {
    try {
      return OrderSegment.byName(
        html.window.localStorage['$_draftSegmentKey.${_soldToReader()}'],
      );
    } catch (_) {
      return null;
    }
  }

  void _writeDraftSegment(OrderSegment segment) {
    try {
      html.window.localStorage['$_draftSegmentKey.${_soldToReader()}'] =
          segment.name;
    } catch (e) {
      logSegment("Could not save the drafts' segment in localStorage: $e");
    }
  }

  static String _readSoldTo() {
    try {
      return Get.find<UserController>(tag: 'userController')
          .rxUserDetail
          .value
          .soldToNumber;
    } catch (_) {
      return '';
    }
  }

  /// Forgets the segment; the next login asks again, locked to
  /// [draftSegment] while there are drafts.
  static void clearStored() {
    try {
      html.window.sessionStorage.remove(_storageKey);

      logSegment('Cleared on logout');
    } catch (_) {}
  }

  static String _describe(OrderSegment segment) =>
      '"${segment.title}" (${segment.code}), JDE categories '
      '${segment.categories.join(', ')}';

  String? _readStorage() {
    try {
      return html.window.sessionStorage[_storageKey];
    } catch (_) {
      return null;
    }
  }

  void _writeStorage(String value) {
    try {
      html.window.sessionStorage[_storageKey] = value;
    } catch (e) {
      logSegment('Could not save the segment in sessionStorage: $e');
    }
  }
}
