import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/orders/direct_delivery_tc.dart';

class _Form extends GetxController with DirectDeliveryTc {
  @override
  final rxArticle = ''.obs;

  @override
  final rxRemark = ''.obs;

  @override
  final rxBillingType = 'Branch'.obs;

  _Form() {
    initDirectDeliveryTc();
  }
}

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
}
