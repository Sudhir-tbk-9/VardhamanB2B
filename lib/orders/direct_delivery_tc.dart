import 'package:get/get.dart';
import 'package:vardhman_b2b/drift/database.dart';

/// "Direct delivery - TC required" on the DTM and Bulk order forms.
///
/// An article with an "R" anywhere in its code (RS826, R0100, MAR235,
/// HR8933) offers the tick box. Ticked, the line is placed as direct
/// delivery: billed direct (DraftTable billingType 'Plant', sent as
/// BillingType 'D') with "TC Required" in its remarks. Left unticked, or for
/// any other article, the line is a normal order.
mixin DirectDeliveryTc on GetxController {
  RxString get rxArticle;

  RxString get rxRemark;

  RxString get rxBillingType;

  static const tcRequiredRemark = 'TC Required';

  /// The tick box; only counts while [offersTc].
  final rxTcRequired = false.obs;

  /// Whether the article picked offers the tick box.
  bool get offersTc => rxArticle.value.toUpperCase().contains('R');

  bool get isTcLine => rxTcRequired.value && offersTc;

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
