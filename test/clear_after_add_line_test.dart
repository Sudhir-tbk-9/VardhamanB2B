import 'dart:ffi' show DynamicLibrary;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vardhman_b2b/bulk/create_bulk_order_view.dart';
import 'package:vardhman_b2b/common/catalog_search_field.dart';
import 'package:vardhman_b2b/common/new_order_text_field.dart';
import 'package:get/get.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/open.dart';
import 'package:vardhman_b2b/api/item_catalog_info.dart';
import 'package:vardhman_b2b/api/user_address.dart';
import 'package:vardhman_b2b/bulk/bulk_entry_controller.dart';
import 'package:vardhman_b2b/catalog/catalog_controller.dart';
import 'package:vardhman_b2b/drift/database.dart';
import 'package:vardhman_b2b/dtm/dtm_entry_controller.dart';
import 'package:vardhman_b2b/labdip/labdip_entry_controller.dart';
import 'package:vardhman_b2b/sampling/sampling_entry_controller.dart';
import 'package:vardhman_b2b/orders/order_review_controller.dart';
import 'package:vardhman_b2b/segment/segment_controller.dart';
import 'package:vardhman_b2b/user/user_controller.dart';

final _user = UserDetail(
  soldToNumber: '1001',
  isMobileUser: false,
  mobileNumber: '',
  canSendSMS: false,
  whatsAppNumber: '',
  canSendWhatsApp: false,
  email: '',
  name: 'Buyer',
  companyCode: '',
  companyName: '',
  role: '',
  category: '',
  discountPercent: 0,
);

class _FakeUserController extends GetxController implements UserController {
  @override
  final rxUserDetail = _user.obs;

  @override
  final rxDeliveryAddress = Rxn<UserAddress>();

  @override
  final rxDeliveryAddresses = RxList<UserAddress>();

  @override
  String lastMerchandiser = '';

  @override
  String get shipToNumber => '1001';

  @override
  String get branchPlant => '';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCatalogController extends GetxController
    implements CatalogController {
  @override
  List<ItemCatalogInfo> get orderItems => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeOrderReviewController extends GetxController
    implements OrderReviewController {
  @override
  String getUomDescription(String uom) => 'Cones';

  @override
  String get shipToDisplay => 'Ludhiana';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  open.overrideFor(
    OperatingSystem.windows,
    () => DynamicLibrary.open('winsqlite3.dll'),
  );

  late Database database;

  setUp(() {
    database = Get.put(Database.forTesting(NativeDatabase.memory()));
    Get.put<UserController>(_FakeUserController(), tag: 'userController');
    Get.put<CatalogController>(_FakeCatalogController());
    Get.put<OrderReviewController>(_FakeOrderReviewController());
    Get.put(SegmentController(draftOrdersLoader: () async => []));
  });

  tearDown(() async {
    await database.close();
    Get.reset();
  });

  String fields(BulkEntryController c) => {
        'article': c.rxArticle.value,
        'brand': c.rxBrand.value,
        'shade': c.rxShade.value,
        'uom': c.rxUom.value,
        'uomWithDesc': c.rxUomWithDesc.value,
        'ticket': c.rxTicket.value,
        'color': c.rxColor.value,
        'price': c.rxUnitPrice.value,
        'qty': c.rxQuantity.value,
      }.toString();

  test('Add Line keeps the article, clears shade, UOM, ticket and quantity',
      () async {
    final c = BulkEntryController(orderNumber: 1);

    c.rxMerchandiser.value = 'M';
    c.rxBuyerName.value = 'B';
    c.rxFirstLightSource.value = 'D65';
    c.rxPoNumber.value = 'PO1';

    // As the user enters a line.
    c.rxArticle.value = 'A100';
    c.rxBrand.value = 'BR';
    c.rxTex.value = '40';
    c.rxSubstrate.value = 'PES';
    c.rxUomWithDesc.value = 'CN - Cones';
    c.rxShade.value = 'S1';
    c.rxTicket.value = 'T1';
    c.rxColor.value = 'RED';
    c.rxQuantity.value = '5';

    await Future<void>.delayed(const Duration(milliseconds: 200));
    // ignore: avoid_print
    print('before add: ${fields(c)}');

    c.addBulkOrderLine();
    // ignore: avoid_print
    print('right after add: ${fields(c)}');

    await Future<void>.delayed(const Duration(seconds: 2));
    // ignore: avoid_print
    print('2s after add: ${fields(c)} lines=${c.rxBulkOrderLines.length}');

    expect(c.rxBulkOrderLines, hasLength(1));
    expect(c.rxArticle.value, 'A100');
    expect(c.rxBrand.value, 'BR');
    expect(c.rxShade.value, '');
    expect(c.rxUom.value, '');
    expect(c.rxTicket.value, '');
    expect(c.rxColor.value, '');
    expect(c.rxQuantity.value, '');
  });

  testWidgets('Add Line on the form shows Shade and Quantity empty',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final c = Get.put(BulkEntryController(orderNumber: 1));

    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: CreateBulkOrderView())),
    );

    await tester.runAsync(() async {
      c.rxMerchandiser.value = 'M';
      c.rxBuyerName.value = 'B';
      c.rxFirstLightSource.value = 'D65';
      c.rxPoNumber.value = 'PO1';
      c.rxArticle.value = 'A100';
      c.rxBrand.value = 'BR';
      c.rxUomWithDesc.value = 'CN - Cones';
      c.rxShade.value = 'S1';
      c.rxColor.value = 'RED';
      c.rxQuantity.value = '57';
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    expect(find.text('S1'), findsWidgets);
    expect(find.text('57'), findsOneWidget);

    await tester.tap(find.text('Add Line'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // ignore: avoid_print
    print('after Add Line: ${fields(c)} lines=${c.rxBulkOrderLines.length}');

    expect(c.rxBulkOrderLines, hasLength(1));
    expect(find.text('A100'), findsWidgets);
    // Shade and Quantity fields: only the saved line in the table may show
    // them now.
    expect(
      find.descendant(
        of: find.byType(CatalogSearchField),
        matching: find.text('S1'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(NewOrderTextField),
        matching: find.text('57'),
      ),
      findsNothing,
    );
  });

  test('DTM Add Line keeps the article, clears the line fields', () async {
    final c = DtmEntryController(orderNumber: 2);

    c.rxMerchandiser.value = 'M';
    c.rxBuyerName.value = 'B';
    c.rxFirstLightSource.value = 'D65';
    c.rxPoNumber.value = 'PO1';
    c.rxArticle.value = 'A100';
    c.rxBrand.value = 'BR';
    c.rxUomWithDesc.value = 'CN - Cones';
    c.rxShade.value = 'SWT001';
    c.rxColor.value = 'RED';
    c.rxQuantity.value = '5';
    await Future<void>.delayed(const Duration(milliseconds: 200));

    c.addDtmOrderLine();
    await Future<void>.delayed(const Duration(seconds: 1));

    expect(c.rxDtmOrderLines, hasLength(1));
    expect(c.rxArticle.value, 'A100');
    expect(c.rxBrand.value, 'BR');
    expect(c.rxShade.value, '');
    expect(c.rxUom.value, '');
    expect(c.rxTicket.value, '');
    expect(c.rxColor.value, '');
    expect(c.rxQuantity.value, '');
  });

  for (final kind in ['Labdip', 'Sampling']) {
    test('$kind Add Line keeps the article, clears Shade, UOM, Color, L/A/B',
        () async {
      final dynamic c = kind == 'Labdip'
          ? LabdipEntryController(orderNumber: 3)
          : SamplingEntryController(orderNumber: 4);

      c.rxMerchandiser.value = 'M';
      c.rxBuyerName.value = 'B';
      c.rxFirstLightSource.value = 'D65';
      c.rxArticle.value = 'A100';
      c.rxBrand.value = 'BR';
      c.rxUomWithDesc.value = 'CN - Cones';
      c.rxShade.value = 'SWT001';
      c.rxColor.value = 'RED';
      c.rxL.value = '50';
      c.rxA.value = '10';
      c.rxB.value = '-5';
      await Future<void>.delayed(const Duration(milliseconds: 200));

      c.addLapdipOrderLine();
      await Future<void>.delayed(const Duration(seconds: 1));

      final lines = kind == 'Labdip'
          ? c.rxLabdipOrderLines as List
          : c.rxSamplingOrderLines as List;

      expect(lines, hasLength(1));
      expect(c.rxArticle.value, 'A100');
      expect(c.rxBrand.value, 'BR');
      expect(c.rxShade.value, '');
      expect(c.rxUom.value, '');
      expect(c.rxTicket.value, '');
      expect(c.rxColor.value, '');
      expect(c.rxL.value, '');
      expect(c.rxA.value, '');
      expect(c.rxB.value, '');
    });
  }
}
