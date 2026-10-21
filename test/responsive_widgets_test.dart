import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vardhman_b2b/common/adaptive_dialog.dart';
import 'package:vardhman_b2b/common/adaptive_row.dart';
import 'package:vardhman_b2b/common/master_detail_layout.dart';
import 'package:vardhman_b2b/common/min_width_scroll.dart';

/// Pumps [child] in a window of [width] x [height]. Any layout overflow fails
/// the test.
Future<void> pumpAt(
  WidgetTester tester,
  double width,
  Widget child, {
  double height = 800,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  group('MasterDetailLayout', () {
    Widget layout({required bool showDetail, VoidCallback? onBack}) =>
        MasterDetailLayout(
          master: const Text('master'),
          detail: const Text('detail'),
          showDetail: showDetail,
          onBack: onBack ?? () {},
          backLabel: 'Orders',
          detailFlex: 3,
        );

    testWidgets('side by side on a desktop, list at least 360 wide',
        (tester) async {
      await pumpAt(tester, 1280, layout(showDetail: false));

      expect(find.text('master'), findsOneWidget);
      expect(find.text('detail'), findsOneWidget);
      expect(find.text('Orders'), findsNothing);

      // 1272 * 1/4 = 318, raised to the minimum.
      final master = tester.getSize(
        find.ancestor(of: find.text('master'), matching: find.byType(SizedBox)),
      );
      expect(master.width, 360);
    });

    testWidgets('keeps the flex share when it is wider than the minimum',
        (tester) async {
      await pumpAt(tester, 1928, layout(showDetail: false));

      final master = tester.getSize(
        find.ancestor(of: find.text('master'), matching: find.byType(SizedBox)),
      );
      expect(master.width, 480);
    });

    testWidgets('one pane at a time on a phone, back bar calls onBack',
        (tester) async {
      var backs = 0;

      await pumpAt(tester, 360, layout(showDetail: false));
      expect(find.text('master').hitTestable(), findsOneWidget);
      expect(find.text('detail').hitTestable(), findsNothing);

      await pumpAt(
        tester,
        360,
        layout(showDetail: true, onBack: () => backs++),
      );
      expect(find.text('master').hitTestable(), findsNothing);
      expect(find.text('detail').hitTestable(), findsOneWidget);

      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();
      expect(backs, 1);
    });

    testWidgets('pane state survives crossing the breakpoint', (tester) async {
      await pumpAt(
        tester,
        1280,
        MasterDetailLayout(
          master: const TextField(),
          detail: const SizedBox(),
          showDetail: false,
          onBack: () {},
        ),
      );
      await tester.enterText(find.byType(TextField), 'kept');

      tester.view.physicalSize = const Size(360, 800);
      await tester.pump();

      expect(find.text('kept'), findsOneWidget);
    });
  });

  group('AdaptiveRow', () {
    final fields = <Widget>[
      const Expanded(flex: 2, child: TextField()),
      const SizedBox(width: 8),
      const Expanded(flex: 3, child: TextField()),
      const Spacer(),
      const Expanded(child: TextField()),
    ];

    testWidgets('a Row when wide', (tester) async {
      await pumpAt(tester, 1000, AdaptiveRow(children: fields));

      final first = tester.getRect(find.byType(TextField).at(0));
      final second = tester.getRect(find.byType(TextField).at(1));
      expect(first.top, second.top);
      expect(first.width, lessThan(second.width));
    });

    testWidgets('stacked full width when narrow', (tester) async {
      await pumpAt(tester, 360, AdaptiveRow(children: fields));

      final rects = [
        for (var i = 0; i < 3; i++)
          tester.getRect(find.byType(TextField).at(i)),
      ];
      for (final rect in rects) {
        expect(rect.width, 360);
      }
      expect(rects[1].top, greaterThan(rects[0].bottom));
    });

    testWidgets('wraps fields and keeps buttons natural when narrow',
        (tester) async {
      await pumpAt(
        tester,
        360,
        AdaptiveRow(
          narrowLayout: NarrowLayout.wrap,
          children: [
            ...fields,
            const SizedBox(width: 8),
            IconButton(onPressed: () {}, icon: const Icon(Icons.refresh)),
          ],
        ),
      );

      // Two 176-wide fields per line at 360.
      final first = tester.getRect(find.byType(TextField).at(0));
      final second = tester.getRect(find.byType(TextField).at(1));
      final third = tester.getRect(find.byType(TextField).at(2));
      expect(first.width, 176);
      expect(second.top, first.top);
      expect(third.top, greaterThan(first.bottom));
      expect(tester.getSize(find.byType(IconButton)).width, 48);
    });
  });

  group('AdaptiveDialog', () {
    Future<Rect> dialogRectAt(WidgetTester tester, double width) async {
      await pumpAt(
        tester,
        width,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const AdaptiveDialog(
                child: SizedBox(width: 1000, height: 300),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // The dialog's surface: the Dialog widget's own rect includes its inset.
      return tester.getRect(
        find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(Material),
            )
            .first,
      );
    }

    testWidgets('fills a phone', (tester) async {
      final rect = await dialogRectAt(tester, 360);

      expect(rect.width, 360);
    });

    testWidgets('keeps its inset on a desktop', (tester) async {
      final rect = await dialogRectAt(tester, 1280);

      expect(rect.width, 1000);
    });
  });

  group('MinWidthScroll', () {
    testWidgets('scrolls sideways below the minimum', (tester) async {
      await pumpAt(
        tester,
        360,
        const MinWidthScroll(minWidth: 720, child: Text('table')),
      );

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(
        tester
            .getSize(
              find.ancestor(
                  of: find.text('table'), matching: find.byType(SizedBox)),
            )
            .width,
        720,
      );
    });

    testWidgets('leaves wide windows alone', (tester) async {
      await pumpAt(
        tester,
        1280,
        const MinWidthScroll(minWidth: 720, child: Text('table')),
      );

      expect(find.byType(SingleChildScrollView), findsNothing);
    });
  });
}
