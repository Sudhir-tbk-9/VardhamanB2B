import 'dart:ffi' show DynamicLibrary;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/open.dart';
import 'package:toastification/toastification.dart';
import 'package:vardhman_b2b/common/clear_drafts.dart';
import 'package:vardhman_b2b/drift/database.dart';
import 'package:vardhman_b2b/segment/segment_controller.dart';
import 'package:vardhman_b2b/segment/segment_dialog.dart';
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
  });

  tearDown(() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await database.close();
    Get.reset();
  });

  Future<void> addLine(
    String orderType,
    int orderNumber,
    int lineNumber, {
    String soldTo = '1001',
  }) =>
      database.managers.draftTable.create(
        (o) => o(
          article: 'A100',
          billingType: '',
          brand: '',
          buyer: 'B',
          buyerCode: '',
          colorName: '',
          remark: '',
          endUse: '',
          firstLightSource: 'D65',
          lab: '',
          lineNumber: lineNumber,
          orderNumber: orderNumber,
          orderType: orderType,
          quantity: 1,
          requestType: '',
          secondLightSource: '',
          shade: 'S$lineNumber',
          soldTo: soldTo,
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
        ),
      );

  Future<Set<String>> remaining() async => {
        for (final line in await database.managers.draftTable.get())
          '${line.soldTo} ${line.orderType} #${line.orderNumber}',
      };

  Future<void> addDrafts() async {
    await addLine('BK', 1, 1);
    await addLine('BK', 1, 2);
    await addLine('BK', 2, 1);
    await addLine('DT', 3, 1);
    await addLine('LD', 4, 1);
    // Another customer's draft in the same browser.
    await addLine('BK', 9, 1, soldTo: '2002');
  }

  test('one order type: only that tab\'s drafts go', () async {
    await addDrafts();

    expect(await deleteDrafts(orderType: 'BK'), 2);
    expect(await remaining(), {'1001 DT #3', '1001 LD #4', '2002 BK #9'});
  });

  test('one draft: only that order, all its lines', () async {
    await addDrafts();

    expect(await deleteDrafts(orderType: 'BK', orderNumber: 1), 1);
    expect(await remaining(), {
      '1001 BK #2',
      '1001 DT #3',
      '1001 LD #4',
      '2002 BK #9',
    });
  });

  test('all: every draft of this customer, no other customer\'s', () async {
    await addDrafts();

    expect(await deleteDrafts(), 4);
    expect(await remaining(), {'2002 BK #9'});
  });

  testWidgets('Clear Drafts asks first; Cancel keeps them', (tester) async {
    await tester.runAsync(addDrafts);

    await tester.pumpWidget(
      const ToastificationWrapper(
        child: GetMaterialApp(
          home: Scaffold(
            body: Center(
              child: ClearDraftsButton(
                orderType: 'DT',
                confirmTitle: 'Clear all DTM drafts?',
                confirmMessage: 'All 1 DTM draft order(s) will be deleted.',
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Clear Drafts'));
    // Not pumpAndSettle: the button's spinner runs while it asks.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Clear all DTM drafts?'), findsWidgets);
    expect(find.textContaining('This cannot be undone.'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(
      await tester.runAsync(remaining),
      contains('1001 DT #3'),
    );

    await tester.tap(find.text('Clear Drafts'));
    // Not pumpAndSettle: the button's spinner runs while it asks.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Clear'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    // Not pumpAndSettle: it would run the message out.
    await tester.pump();

    expect(
      await tester.runAsync(remaining),
      isNot(contains('1001 DT #3')),
    );
    // The "1 draft cleared" message shows once the real database work
    // is done; let it run out.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Clear all drafts in the segment dialog unlocks the segment',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var cleared = 0;

    final controller = Get.put(
      SegmentController(
        draftOrdersLoader: () async => const [
          DraftOrder(orderType: 'BK', orderNumber: 1024, lineCount: 3),
        ],
        draftsClearer: () async => cleared++,
      ),
    )..select(OrderSegment.industry);

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: const [SegmentHeaderButton()]),
        ),
      ),
    );

    await tester.tap(find.text('IND · Industry'));
    await tester.pumpAndSettle();

    expect(find.text('WARNING'), findsOneWidget);

    await tester.tap(find.text('Clear all drafts'));
    await tester.pumpAndSettle();

    expect(find.text('Clear all drafts?'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(cleared, 1);
    expect(find.text('WARNING'), findsNothing);

    // Unlocked: another segment can be picked now.
    await tester.tap(find.text('Speciality'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(controller.segment, OrderSegment.speciality);
  });
}
