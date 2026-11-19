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

  /// Whether the form shows a Remark field (DTM). With one, a TC line's
  /// Remark field itself reads "TC Required", then the user's remark after
  /// a comma; without one (Bulk), the line's remark is "TC Required".
  bool get hasRemarkField => false;

  /// [remark] without a leading "TC Required" (and the comma after it).
  /// Remarks saved before as "<remark> | TC Required" lose that part too.
  static String withoutTcRemark(String remark) {
    final parts = remark
        .split(' | ')
        .where((part) => part.trim() != tcRequiredRemark)
        .join(' | ')
        .trim();

    if (!parts.startsWith(tcRequiredRemark)) {
      return parts;
    }

    final rest = parts.substring(tcRequiredRemark.length).trimLeft();

    return (rest.startsWith(',') ? rest.substring(1) : rest).trim();
  }

  /// "TC Required", then [remark] after a comma: "TC Required, <remark>".
  static String withTcRemark(String remark) {
    final userRemark = withoutTcRemark(remark);

    return userRemark.isEmpty
        ? tcRequiredRemark
        : '$tcRequiredRemark, $userRemark';
  }

  /// Remark saved with the line (and sent in ColorRemark): "TC Required,
  /// <remark>" for a TC line, otherwise the remark typed.
  String get lineRemark => isTcLine
      ? withTcRemark(rxRemark.value)
      : withoutTcRemark(rxRemark.value);

  static bool isTcRequiredLine(DraftTableData line) =>
      line.billingType == 'Plant';

  /// Fills the tick box and Remark from a saved [line]: the Remark field
  /// shows "TC Required, <remark>" for a TC line.
  void populateTc(DraftTableData line) {
    rxTcRequired.value = isTcRequiredLine(line);

    rxRemark.value = hasRemarkField && isTcRequiredLine(line)
        ? withTcRemark(line.remark)
        : withoutTcRemark(line.remark);
  }

  /// With a Remark field: "TC Required" put at the front of the Remark when
  /// the line becomes a TC line, taken off when it stops being one. The
  /// user's own remark after the comma stays.
  void syncTcRemark() {
    if (!hasRemarkField) {
      return;
    }

    final remark = isTcLine
        ? withTcRemark(rxRemark.value)
        : withoutTcRemark(rxRemark.value);

    if (remark != rxRemark.value) {
      rxRemark.value = remark;
    }
  }

  /// Call once from the controller's constructor: an article without an
  /// "R" drops the tick; the Remark follows the tick ([syncTcRemark]).
  void initDirectDeliveryTc() {
    ever(rxArticle, (_) {
      if (!offersTc) {
        rxTcRequired.value = false;
      }

      syncTcRemark();
    });

    ever(rxTcRequired, (_) => syncTcRemark());

    // A TC order ticks every R line: follows lines added and deleted.
    final lines = tcOrderLines;

    if (lines is RxList<DraftTableData>) {
      ever(lines, (_) => syncTcRemark());
    }

    final selectedLines = tcSelectedLines;

    if (selectedLines is RxList<DraftTableData>) {
      ever(selectedLines, (_) => syncTcRemark());
    }
  }
}
