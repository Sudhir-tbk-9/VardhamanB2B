import 'package:get/get.dart';
import 'package:vardhman_b2b/drift/database.dart';

/// "Tick if TC Required" (direct delivery) on the DTM and Bulk order forms.
///
/// An article with an "R" anywhere in its code (RS826, R0100, MAR235,
/// HR8933) offers the tick box. Ticked, the line is placed as direct
/// delivery: billed direct (DraftTable billingType 'Plant', sent as
/// BillingType 'D') with "TC Required" in its remarks. Left unticked, or for
/// any other article, the line is a normal order.
///
/// An order is all TC lines or none, decided by its first line:
/// - first line TC: only "R" articles can be added, each one a TC line (the
///   box is shown ticked and cannot be unticked);
/// - first line normal (any article, "R" or not, without the tick): the box
///   is not shown, every later line is normal.
/// Lines selected for Update do not count, so the only line of an order can
/// be switched either way.
mixin DirectDeliveryTc on GetxController {
  RxString get rxArticle;

  RxString get rxRemark;

  RxString get rxBillingType;

  /// The order's lines (DraftTable).
  List<DraftTableData> get tcOrderLines => const [];

  /// Lines selected for Update.
  List<DraftTableData> get tcSelectedLines => const [];

  static const tcRequiredRemark = 'TC Required';

  /// The tick box; only counts while [offersTc].
  final rxTcRequired = false.obs;

  static bool isRArticle(String article) => article.toUpperCase().contains('R');

  /// Whether the order is a TC order (true), a normal order (false), or not
  /// decided yet (null: no lines besides those selected for Update).
  bool? get orderIsTc {
    final others = tcOrderLines
        .where((line) => !tcSelectedLines.contains(line))
        .toList()
      ..sort((a, b) => a.lineNumber.compareTo(b.lineNumber));

    return others.isEmpty ? null : isTcRequiredLine(others.first);
  }

  /// The tick box is ticked and locked: a TC order.
  bool get isTcLocked => orderIsTc == true;

  /// Whether [article] can be added to this order: a TC order takes "R"
  /// articles only.
  bool allowsArticle(String article) => !isTcLocked || isRArticle(article);

  /// Whether the article picked offers the tick box; never in a normal
  /// order.
  bool get offersTc => isRArticle(rxArticle.value) && orderIsTc != false;

  bool get isTcLine => offersTc && (rxTcRequired.value || isTcLocked);

  /// Shown when a non-"R" article is entered in a TC order.
  static const onlyRArticlesMessage =
      'This is a TC Required order: only articles with an "R" can be added';

  /// DraftTable billingType of the line being entered.
  String get lineBillingType => isTcLine ? 'Plant' : rxBillingType.value;

  /// Remark saved with the line: the one typed, then "TC Required".
  String get lineRemark => [
        if (rxRemark.value.trim().isNotEmpty) rxRemark.value.trim(),
        if (isTcLine) tcRequiredRemark,
      ].join(' | ');

  static bool isTcRequiredLine(DraftTableData line) =>
      line.billingType == 'Plant';

  /// Fills the tick box and Remark from a saved [line], without the
  /// "TC Required" note [lineRemark] added.
  void populateTc(DraftTableData line) {
    rxTcRequired.value = isTcRequiredLine(line);

    rxRemark.value = line.remark
        .split(' | ')
        .where((part) => part != tcRequiredRemark)
        .join(' | ');
  }

  /// Call once from the controller's constructor: an article without an
  /// "R" drops the tick.
  void initDirectDeliveryTc() {
    ever(rxArticle, (_) {
      if (!offersTc) {
        rxTcRequired.value = false;
      }
    });
  }
}
