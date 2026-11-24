import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:universal_html/html.dart' as html;
import 'package:vardhman_b2b/segment/segment_controller.dart';
import 'package:vardhman_b2b/segment/segment_dialog.dart';

void main() {
  setUp(() {
    SegmentController.clearStored();
    // The segment last picked per customer, kept past a logout.
    html.window.localStorage.clear();
  });

  tearDown(Get.reset);

  test('each segment limits the JDE categories', () {
    // Only IND, SPE and ALL are offered.
    expect(OrderSegment.values, [
      OrderSegment.industry,
      OrderSegment.speciality,
      OrderSegment.all,
    ]);

    expect(OrderSegment.industry.categories, ['IND']);
    expect(OrderSegment.speciality.categories, ['SPE']);

    expect(OrderSegment.all.categories, ['IND', 'SPE', 'DOM']);

    expect(OrderSegment.industry.includesCategory(' ind '), isTrue);
    expect(OrderSegment.industry.includesCategory('SPE'), isFalse);
  });

  test('before a pick the controller uses All Segments', () {
    final controller = SegmentController();

    expect(controller.hasSegment, isFalse);
    expect(controller.categories, OrderSegment.all.categories);

    controller.select(OrderSegment.speciality);

    expect(controller.segment, OrderSegment.speciality);
    expect(controller.categories, ['SPE']);
  });

  testWidgets('the dialog stays open until a segment is picked',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = Get.put(SegmentController());

    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: SizedBox())),
    );

    showSegmentDialogIfNeeded();
    await tester.pumpAndSettle();

    expect(find.text('Choose your segment'), findsOneWidget);

    // Three cards, no label under the title.
    expect(find.text('Industry'), findsOneWidget);
    expect(find.text('Speciality'), findsOneWidget);
    expect(find.text('All Segments'), findsOneWidget);
    expect(find.text('Domestic'), findsNothing);
    expect(find.text('Industry & Speciality'), findsNothing);
    expect(find.text('Industrial threads'), findsNothing);

    // Back / Escape and a tap outside do not close it.
    await tester.binding.handlePopRoute();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.text('Choose your segment'), findsOneWidget);

    // Continue does nothing until a card is picked.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Choose your segment'), findsOneWidget);
    expect(controller.hasSegment, isFalse);

    await tester.tap(find.text('Speciality'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Choose your segment'), findsNothing);
    expect(controller.segment, OrderSegment.speciality);

    // Picked: not shown again.
    showSegmentDialogIfNeeded();
    await tester.pumpAndSettle();

    expect(find.text('Choose your segment'), findsNothing);
  });

  testWidgets('the header button reopens it to change the segment',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = Get.put(SegmentController())
      ..select(OrderSegment.industry);

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: const [SegmentHeaderButton()]),
        ),
      ),
    );

    expect(find.text('IND · Industry'), findsOneWidget);

    await tester.tap(find.text('IND · Industry'));
    await tester.pumpAndSettle();

    expect(find.text('Choose your segment'), findsOneWidget);

    // Already set: the close button leaves it as it was.
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Choose your segment'), findsNothing);
    expect(controller.segment, OrderSegment.industry);

    await tester.tap(find.text('IND · Industry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All Segments'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(controller.segment, OrderSegment.all);
    expect(find.text('ALL · All Segments'), findsOneWidget);
  });

  testWidgets('orders in progress lock the segment and say why',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final opened = <DraftOrder>[];

    final controller = Get.put(
      SegmentController(
        draftOrdersLoader: () async => const [
          DraftOrder(orderType: 'BK', orderNumber: 1024, lineCount: 3),
          DraftOrder(orderType: 'DT', orderNumber: 77, lineCount: 1),
        ],
        draftOrderOpener: (draftOrder) async {
          opened.add(draftOrder);

          Get.back();
        },
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

    // Why it is locked, and where each draft is.
    expect(find.text('WARNING'), findsOneWidget);
    expect(
      find.text("An order can't mix segments. Submit or delete these "
          'drafts to switch.'),
      findsOneWidget,
    );
    expect(find.text('Bulk draft #1024'), findsOneWidget);
    expect(find.text('DTM draft #77'), findsOneWidget);
    expect(find.textContaining('lines'), findsNothing);

    // Other cards cannot be picked; OK closes without a change.
    await tester.tap(find.text('Speciality'));
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Choose your segment'), findsNothing);
    expect(controller.segment, OrderSegment.industry);

    // Clicking a draft opens it.
    await tester.tap(find.text('IND · Industry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DTM draft #77'));
    await tester.pumpAndSettle();

    expect(opened.single.orderNumber, 77);
    expect(find.text('Choose your segment'), findsNothing);
    expect(controller.segment, OrderSegment.industry);
  });

  test('drafts name the tab that lists them', () {
    const labdip = DraftOrder(orderType: 'LD', orderNumber: 5, lineCount: 2);

    expect(labdip.tabName, 'Labdip');
    expect(labdip.tabPath, '/labdip');
    expect(
      const DraftOrder(orderType: 'BK', orderNumber: 1, lineCount: 1).tabPath,
      '/bulk',
    );
  });

  // A picked card has the check badge in its row.
  bool isPicked(WidgetTester tester, String title) => find
      .descendant(
        of: find
            .ancestor(of: find.text(title), matching: find.byType(Row))
            .first,
        matching: find.byIcon(Icons.check),
      )
      .evaluate()
      .isNotEmpty;

  testWidgets(
      'after Logout, the next login shows the dialog with the segment '
      'picked last; Continue keeps it', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SegmentController login({String soldTo = '1001'}) => SegmentController(
          draftOrdersLoader: () async => const [],
          soldToReader: () => soldTo,
        );

    // First session: Speciality picked, then Logout clicked.
    login()
      ..select(OrderSegment.speciality)
      ..askOnNextLogin();
    SegmentController.clearStored();

    // Another customer on this browser has not picked one: asked as before.
    expect(login(soldTo: '2002').hasSegment, isFalse);

    // Next login: in Speciality, and the dialog shows it picked.
    final controller = Get.put(login());

    expect(controller.segment, OrderSegment.speciality);
    expect(controller.isLoginConfirmationPending, isTrue);

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: const [SegmentHeaderButton()]),
        ),
      ),
    );

    showSegmentDialogIfNeeded();
    await tester.pumpAndSettle();

    expect(find.text('Choose your segment'), findsOneWidget);
    expect(isPicked(tester, 'Speciality'), isTrue);
    expect(isPicked(tester, 'Industry'), isFalse);

    // No line about which articles the segment offers.
    expect(find.textContaining('will be offered'), findsNothing);

    // Not closed without Continue: no close button, Back and a tap outside
    // do nothing.
    expect(find.byTooltip('Close'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.text('Choose your segment'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Choose your segment'), findsNothing);
    expect(controller.segment, OrderSegment.speciality);
    expect(controller.isLoginConfirmationPending, isFalse);

    // Shown once per login.
    showSegmentDialogIfNeeded();
    await tester.pumpAndSettle();

    expect(find.text('Choose your segment'), findsNothing);

    // And only on the login right after Logout.
    SegmentController.clearStored();

    expect(login().isLoginConfirmationPending, isFalse);
  });

  testWidgets(
      'after the inactivity logout, the next login starts in the segment '
      'picked last with no dialog, as before', (tester) async {
    SegmentController login() => SegmentController(
          draftOrdersLoader: () async => const [],
          soldToReader: () => '1001',
        );

    // Speciality picked, then logged out after 5 minutes idle (no Logout
    // click, so askOnNextLogin is not called).
    login().select(OrderSegment.speciality);
    SegmentController.clearStored();

    final controller = Get.put(login());

    expect(controller.segment, OrderSegment.speciality);
    expect(controller.isLoginConfirmationPending, isFalse);

    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: SizedBox())),
    );

    showSegmentDialogIfNeeded();
    await tester.pumpAndSettle();

    expect(find.text('Choose your segment'), findsNothing);
  });

  testWidgets(
      'after Logout, the segment can be changed in the login dialog; the '
      'header still switches it', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SegmentController login() => SegmentController(
          draftOrdersLoader: () async => const [],
          soldToReader: () => '1001',
        );

    login()
      ..select(OrderSegment.speciality)
      ..askOnNextLogin();
    SegmentController.clearStored();

    final controller = Get.put(login());

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: const [SegmentHeaderButton()]),
        ),
      ),
    );

    showSegmentDialogIfNeeded();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Industry'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(controller.segment, OrderSegment.industry);
    expect(find.text('IND · Industry'), findsOneWidget);

    // From the header it can be closed without changing it.
    await tester.tap(find.text('IND · Industry'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Close'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(controller.segment, OrderSegment.industry);

    // The login after that starts in Industry.
    SegmentController.clearStored();

    expect(login().segment, OrderSegment.industry);
  });

  testWidgets('a page refresh or payment return keeps the segment, no dialog',
      (tester) async {
    SegmentController login() => SegmentController(
          draftOrdersLoader: () async => const [],
          soldToReader: () => '1001',
        );

    // Picked in this session; not logged out (sessionStorage kept).
    login().select(OrderSegment.speciality);

    final controller = Get.put(login());

    expect(controller.segment, OrderSegment.speciality);
    expect(controller.isLoginConfirmationPending, isFalse);

    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: SizedBox())),
    );

    showSegmentDialogIfNeeded();
    await tester.pumpAndSettle();

    expect(find.text('Choose your segment'), findsNothing);
  });

  testWidgets('after a re-login, drafts keep the segment locked',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var drafts = <DraftOrder>[];

    SegmentController login() => SegmentController(
          draftOrdersLoader: () async => drafts,
          soldToReader: () => '1001',
        );

    // First session: Speciality picked, a Bulk draft saved, logged out.
    login().select(OrderSegment.speciality);
    drafts = const [
      DraftOrder(orderType: 'BK', orderNumber: 1024, lineCount: 2)
    ];
    SegmentController.clearStored();

    // Next login: in Speciality; switching shows the lock.
    final controller = Get.put(login());

    expect(controller.segment, OrderSegment.speciality);

    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: SizedBox())),
    );

    showSegmentDialog();
    await tester.pumpAndSettle();

    expect(find.text('WARNING'), findsOneWidget);
    expect(find.text('Bulk draft #1024'), findsOneWidget);

    await tester.tap(find.text('Industry'));
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(controller.segment, OrderSegment.speciality);
  });
}
