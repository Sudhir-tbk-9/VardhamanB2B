import 'package:flutter/material.dart';
import 'package:vardhman_b2b/common/breakpoints.dart';
import 'package:vardhman_b2b/common/secondary_button.dart';
import 'package:vardhman_b2b/constants.dart';

/// A list ([master]) and its details ([detail]): side by side when there is
/// room ([Breakpoints.split]), otherwise one at a time.
///
/// Side by side, the list takes its [masterFlex] share of the width but never
/// less than [masterMinWidth] (nor more than half), so it stays readable on
/// a laptop. One at a time, [showDetail] picks the pane and the details get a
/// back bar that calls [onBack]. Both panes stay built in either layout, and
/// keep their state (scroll position, entered text) when the window is
/// resized across the breakpoint.
class MasterDetailLayout extends StatefulWidget {
  const MasterDetailLayout({
    super.key,
    required this.master,
    required this.detail,
    required this.showDetail,
    required this.onBack,
    this.backLabel = 'Back',
    this.masterBar,
    this.masterFlex = 1,
    this.detailFlex = 1,
    this.masterMinWidth = 360,
  });

  final Widget master, detail;

  /// Which pane shows when there is room for only one.
  final bool showDetail;

  /// Called by the details' back bar when there is room for only one pane.
  final VoidCallback onBack;

  final String backLabel;

  /// Shown under the list when there is room for only one pane, for lists
  /// whose details are not opened by picking a row (e.g. a button that opens
  /// the review of the selected invoices).
  final Widget? masterBar;

  final int masterFlex, detailFlex;

  final double masterMinWidth;

  @override
  State<MasterDetailLayout> createState() => _MasterDetailLayoutState();
}

class _MasterDetailLayoutState extends State<MasterDetailLayout> {
  // Let each pane move between the two layouts without being rebuilt.
  final _masterKey = GlobalKey();
  final _detailKey = GlobalKey();

  static const _dividerWidth = 8.0;

  @override
  Widget build(BuildContext context) {
    final master = KeyedSubtree(key: _masterKey, child: widget.master);
    final detail = KeyedSubtree(key: _detailKey, child: widget.detail);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= Breakpoints.split) {
          final available = constraints.maxWidth - _dividerWidth;

          final masterWidth = (available *
                  widget.masterFlex /
                  (widget.masterFlex + widget.detailFlex))
              .clamp(widget.masterMinWidth, available / 2);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(width: masterWidth, child: master),
              VerticalDivider(
                thickness: _dividerWidth,
                width: _dividerWidth,
                color: VardhmanColors.darkGrey,
              ),
              Expanded(child: detail),
            ],
          );
        }

        return IndexedStack(
          index: widget.showDetail ? 1 : 0,
          sizing: StackFit.expand,
          children: <Widget>[
            if (widget.masterBar == null)
              master
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(child: master),
                  Material(
                    color: Colors.white,
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: widget.masterBar,
                    ),
                  ),
                ],
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Material(
                  color: Colors.white,
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SecondaryButton(
                        iconData: Icons.arrow_back_ios_new,
                        text: widget.backLabel,
                        onPressed: () async => widget.onBack(),
                      ),
                    ),
                  ),
                ),
                Expanded(child: detail),
              ],
            ),
          ],
        );
      },
    );
  }
}
