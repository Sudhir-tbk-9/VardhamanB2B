import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_html/html.dart' as html;
import 'package:vardhman_b2b/drift/database.dart';
import 'package:vardhman_b2b/user/user_controller.dart';

/// Business segment the user orders in, picked once after login. Articles
/// are matched on their JDE category code (F4101.SRP1, `Category` in the
/// item catalog).
enum OrderSegment {
  industry(
    code: 'IND',
    title: 'Industry',
    subtitle: 'Industrial threads',
    icon: Icons.precision_manufacturing_outlined,
    categories: ['IND'],
  ),
  domestic(
    code: 'DOM',
    title: 'Domestic',
    subtitle: 'Domestic threads',
    icon: Icons.storefront_outlined,
    categories: ['DOM'],
  ),
  speciality(
    code: 'SPE',
    title: 'Speciality',
    subtitle: 'Speciality threads',
    icon: Icons.auto_awesome_outlined,
    categories: ['SPE'],
  ),
  industryAndSpeciality(
    code: 'IND + SPE',
    title: 'Industry & Speciality',
    subtitle: 'Both IND and SPE articles',
    icon: Icons.join_inner_outlined,
    categories: ['IND', 'SPE'],
  ),

  /// No segment restriction: articles of every segment.
  all(
    code: 'ALL',
    title: 'All Segments',
    subtitle: 'Articles of every segment',
    icon: Icons.all_inclusive,
    categories: ['IND', 'SPE', 'DOM'],
  );

  final String code;
  final String title;
  final String subtitle;
  final IconData icon;

  /// JDE category codes (F4101.SRP1) of the articles offered.
  final List<String> categories;

  const OrderSegment({
    required this.code,
    required this.title,
    required this.subtitle,
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

  @override
  String toString() =>
      '$typeName draft #$orderNumber ($lineCount line${lineCount == 1 ? '' : 's'})';
}

typedef DraftOrdersLoader = Future<List<DraftOrder>> Function();

/// Console log of the segment flow, tagged `[SEGMENT]` so it can be
/// filtered in the browser console (debugPrint, so release builds log too).
void logSegment(String message) => debugPrint('[SEGMENT] $message');

/// The segment of the logged in user. Kept in the tab's sessionStorage, like
/// the login itself (see LoginController), so a page refresh keeps it and
/// logging out forgets it.
class SegmentController extends GetxController {
  static const _storageKey = 'orderSegment';

  /// Null until the user picks one in the segment dialog.
  final rxSegment = Rxn<OrderSegment>();

  /// Whether the segment dialog is on screen, so it is not opened twice.
  bool isDialogOpen = false;

  final DraftOrdersLoader _draftOrdersLoader;

  /// [draftOrdersLoader] replaces the DraftTable read, for tests.
  SegmentController({DraftOrdersLoader? draftOrdersLoader})
      : _draftOrdersLoader = draftOrdersLoader ?? _loadDraftOrders {
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

  /// Forgets the segment; the next login asks again.
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
