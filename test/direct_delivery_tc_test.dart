import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/drift/database.dart';
import 'package:vardhman_b2b/orders/direct_delivery_tc.dart';

class _Form extends GetxController with DirectDeliveryTc {
  @override
  final rxArticle = ''.obs;

  @override
  final rxRemark = ''.obs;

  @override
  final rxBillingType = 'Branch'.obs;

  final lines = <DraftTableData>[].obs;

  final selectedLines = <DraftTableData>[].obs;

  @override
  List<DraftTableData> get tcOrderLines => lines;

  @override
  List<DraftTableData> get tcSelectedLines => selectedLines;

  _Form() {
    initDirectDeliveryTc();
  }
}

/// A saved line: a TC line when [tc] (billingType 'Plant').
DraftTableData _line(int lineNumber, String article, {bool tc = false}) =>
    DraftTableData(
      id: lineNumber,
      soldTo: '1001',
      orderType: 'BK',
      orderNumber: 1,
      merchandiser: 'M',
      lineNumber: lineNumber,
      shade: 'S$lineNumber',
      buyer: 'B',
      buyerCode: '',
      firstLightSource: 'D65',
      secondLightSource: '',
      substrate: '',
      tex: '',
      ticket: '',
      brand: '',
      article: article,
      requestType: '',
      colorName: '',
      lab: ',,',
      remark: tc ? DirectDeliveryTc.tcRequiredRemark : '',
      billingType: tc ? 'Plant' : 'Branch',
      uom: 'CN',
      endUse: '',
      quantity: 1,
      colorRemark: '',
      lastUpdated: DateTime(2026),
      qtxFileName: '',
      poNumber: 'PO1',
      poFileName: '',
    );

void main() {
  test('any article with an R offers the tick box', () {
    final form = _Form();

    for (final article in ['RS826', 'R0100', 'MAR235', 'HR8933', 'hr8933']) {
      form.rxArticle.value = article;

      expect(form.offersTc, isTrue, reason: article);
    }

    for (final article in ['', 'S826', 'A100', 'DT5050']) {
      form.rxArticle.value = article;

      expect(form.offersTc, isFalse, reason: article);
    }
  });

  test('ticked: direct delivery with TC Required in the remark', () {
    final form = _Form()
      ..rxArticle.value = 'MAR235'
      ..rxRemark.value = 'URGENT'
      ..rxTcRequired.value = true;

    expect(form.isTcLine, isTrue);
    expect(form.lineBillingType, 'Plant');
    expect(form.lineRemark, 'URGENT | TC Required');
  });

  test('not ticked: a normal order', () {
    final form = _Form()
      ..rxArticle.value = 'MAR235'
      ..rxRemark.value = 'URGENT';

    expect(form.isTcLine, isFalse);
    expect(form.lineBillingType, 'Branch');
    expect(form.lineRemark, 'URGENT');
  });

  test('changing to an article without an R drops the tick', () {
    final form = _Form()
      ..rxArticle.value = 'RS826'
      ..rxTcRequired.value = true;

    form.rxArticle.value = 'A100';

    expect(form.rxTcRequired.value, isFalse);
    expect(form.lineBillingType, 'Branch');

    // Back to an R article: the tick does not come back by itself.
    form.rxArticle.value = 'RS826';

    expect(form.isTcLine, isFalse);
  });

  group('the first line decides: a TC order or a normal order', () {
    test('no lines yet: every article, the box for R articles', () {
      final form = _Form()..rxArticle.value = 'RS826';

      expect(form.orderIsTc, isNull);
      expect(form.allowsArticle('A100'), isTrue);
      expect(form.offersTc, isTrue);
      expect(form.isTcLocked, isFalse);
    });

    test('first line TC: R articles only, box ticked and locked', () {
      final form = _Form()..lines.add(_line(1, 'RS826', tc: true));

      expect(form.orderIsTc, isTrue);
      expect(form.allowsArticle('A100'), isFalse);
      expect(form.allowsArticle('MAR235'), isTrue);

      form.rxArticle.value = 'MAR235';

      // Not ticked by the user, still a TC line.
      expect(form.rxTcRequired.value, isFalse);
      expect(form.isTcLocked, isTrue);
      expect(form.isTcLine, isTrue);
      expect(form.lineBillingType, 'Plant');
      expect(form.lineRemark, 'TC Required');
    });

    test('first line normal: no box, even for an R article', () {
      final form = _Form()
        ..lines.add(_line(1, 'A100'))
        ..rxArticle.value = 'RS826'
        ..rxTcRequired.value = true;

      expect(form.orderIsTc, isFalse);
      expect(form.allowsArticle('A100'), isTrue);
      expect(form.offersTc, isFalse);
      expect(form.isTcLine, isFalse);
      expect(form.lineBillingType, 'Branch');
    });

    test('first line an R article left unticked: a normal order', () {
      final form = _Form()
        ..lines.add(_line(1, 'RS826'))
        ..rxArticle.value = 'MAR235';

      expect(form.orderIsTc, isFalse);
      expect(form.offersTc, isFalse);
    });

    test('decided by the lowest line number, not the order added', () {
      final form = _Form()
        ..lines.addAll([_line(2, 'A100'), _line(1, 'RS826', tc: true)]);

      expect(form.orderIsTc, isTrue);
    });

    test('the only line, selected for Update, can be switched', () {
      final only = _line(1, 'RS826', tc: true);
      final form = _Form()
        ..lines.add(only)
        ..selectedLines.add(only);

      expect(form.orderIsTc, isNull);
      expect(form.allowsArticle('A100'), isTrue);
      expect(form.isTcLocked, isFalse);
    });

    test('updating a later line follows the first line', () {
      final second = _line(2, 'MAR235', tc: true);
      final form = _Form()
        ..lines.addAll([_line(1, 'RS826', tc: true), second])
        ..selectedLines.add(second);

      expect(form.isTcLocked, isTrue);
      expect(form.allowsArticle('A100'), isFalse);
    });

    test('deleting every line lifts the rule', () {
      final form = _Form()..lines.add(_line(1, 'RS826', tc: true));

      form.lines.clear();

      expect(form.orderIsTc, isNull);
      expect(form.allowsArticle('A100'), isTrue);
    });
  });
}
