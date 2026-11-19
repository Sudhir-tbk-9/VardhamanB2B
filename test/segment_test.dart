import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/segment/segment_controller.dart';
import 'package:vardhman_b2b/segment/segment_dialog.dart';

void main() {
  setUp(SegmentController.clearStored);

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
}
