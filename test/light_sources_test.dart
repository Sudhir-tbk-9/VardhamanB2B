import 'package:flutter_test/flutter_test.dart';
import 'package:vardhman_b2b/common/light_sources.dart';
import 'package:vardhman_b2b/drift/database.dart';

DraftTableData _line(String first, String second) => DraftTableData(
      id: 1,
      article: 'A100',
      billingType: '',
      brand: '',
      buyer: 'B',
      buyerCode: '',
      colorName: '',
      remark: '',
      endUse: '',
      firstLightSource: first,
      lab: '',
      lineNumber: 1,
      orderNumber: 1,
      orderType: 'BK',
      quantity: 1,
      requestType: '',
      secondLightSource: second,
      shade: 'S1',
      soldTo: '1001',
      substrate: '',
      tex: '',
      ticket: '',
      uom: 'CN',
      colorRemark: '',
      lastUpdated: DateTime(2026),
      merchandiser: 'M',
      qtxFileName: '',
      poNumber: '',
      poFileName: '',
    );

void main() {
  test('Light Source column: both light sources, empty ones left out', () {
    expect(_line('D65', 'U35').lightSourcesText, 'D65, U35');
    expect(_line('D65', '').lightSourcesText, 'D65');
    expect(_line('', 'TL84').lightSourcesText, 'TL84');
    expect(_line(' D65 ', '  ').lightSourcesText, 'D65');
    expect(_line('', '').lightSourcesText, '');
  });
}
