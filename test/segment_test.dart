import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/segment/segment_controller.dart';
import 'package:vardhman_b2b/segment/segment_dialog.dart';

void main() {
  setUp(SegmentController.clearStored);

  tearDown(Get.reset);

  test('each segment limits the JDE categories', () {
    expect(OrderSegment.industry.categories, ['IND']);
    expect(OrderSegment.domestic.categories, ['DOM']);
    expect(OrderSegment.speciality.categories, ['SPE']);
    expect(OrderSegment.industryAndSpeciality.categories, ['IND', 'SPE']);

    expect(OrderSegment.all.categories, ['IND', 'SPE', 'DOM']);

    expect(OrderSegment.industry.includesCategory(' ind '), isTrue);
    expect(OrderSegment.industry.includesCategory('SPE'), isFalse);
  });

  test('before a pick the controller uses All Segments', () {
    final controller = SegmentController();

    expect(controller.hasSegment, isFalse);
    expect(controller.categories, OrderSegment.all.categories);

    controller.select(OrderSegment.domestic);

    expect(controller.segment, OrderSegment.domestic);
    expect(controller.categories, ['DOM']);
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
    await tester.tap(find.text('Domestic'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(controller.segment, OrderSegment.domestic);
    expect(find.text('DOM · Domestic'), findsOneWidget);
  });

  testWidgets('orders in progress lock the segment and say why',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = Get.put(
      SegmentController(
        draftOrdersLoader: () async => const [
          DraftOrder(orderType: 'BK', orderNumber: 1024, lineCount: 3),
          DraftOrder(orderType: 'DT', orderNumber: 77, lineCount: 1),
        ],
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

    expect(find.text('Segment locked to Industry (IND)'), findsOneWidget);
    expect(find.text('Bulk draft #1024 (3 lines)'), findsOneWidget);
    expect(find.text('DTM draft #77 (1 line)'), findsOneWidget);

    // Other cards cannot be picked; OK closes without a change.
    await tester.tap(find.text('Domestic'));
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Choose your segment'), findsNothing);
    expect(controller.segment, OrderSegment.industry);
  });
}
