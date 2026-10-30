import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vardhman_b2b/common/breakpoints.dart';
import 'package:vardhman_b2b/common/secondary_button.dart';
import 'package:vardhman_b2b/constants.dart';

/// A list ([master]) and its details ([detail]): side by side when there is
/// room ([Breakpoints.split]), otherwise one at a time.
///
/// Side by side, the list takes its [masterFlex] share of the width but never
/// less than [masterMinWidth] (nor more than half), so it stays readable on
/// a laptop. Dragging the divider between them resizes the list (kept under
/// [storageKey]). One at a time, [showDetail] picks the pane and the details get a
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
    this.detailMinWidth = 360,
    this.storageKey,
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

  /// Narrowest the details get when the divider is dragged.
  final double detailMinWidth;

  /// Saves the list's width, as dragged, under this name, so each screen
  /// opens at the width last chosen for it. Not saved when null.
  final String? storageKey;

  @override
  State<MasterDetailLayout> createState() => _MasterDetailLayoutState();
}

class _MasterDetailLayoutState extends State<MasterDetailLayout> {
  // Let each pane move between the two layouts without being rebuilt.
  final _masterKey = GlobalKey();
  final _detailKey = GlobalKey();

  static const _dividerWidth = 8.0;

  /// The list's share of the width as dragged, or null for the default
  /// ([MasterDetailLayout.masterFlex]).
  double? _masterShare;

  /// Pointer position and list width when the divider drag began.
  double _dragStartX = 0, _dragStartWidth = 0;

  SharedPreferences? get _sharedPrefs =>
      Get.isRegistered<SharedPreferences>()
          ? Get.find<SharedPreferences>()
          : null;

  String? get _prefsKey => widget.storageKey == null
      ? null
      : 'masterDetailShare_${widget.storageKey}';

  @override
  void initState() {
    super.initState();

    final prefsKey = _prefsKey;

    if (prefsKey != null) {
      _masterShare = _sharedPrefs?.getDouble(prefsKey);
    }
  }

  void _saveMasterShare() {
    final prefsKey = _prefsKey;

    if (prefsKey == null) {
      return;
    }

    final masterShare = _masterShare;

    if (masterShare == null) {
      _sharedPrefs?.remove(prefsKey);
    } else {
      _sharedPrefs?.setDouble(prefsKey, masterShare);
    }
  }

  @override
  Widget build(BuildContext context) {
    final master = KeyedSubtree(key: _masterKey, child: widget.master);
    final detail = KeyedSubtree(key: _detailKey, child: widget.detail);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= Breakpoints.split) {
          final available = constraints.maxWidth - _dividerWidth;

          // Dragged: anywhere that leaves both panes their minimum width.
          final maxMasterWidth = math.max(
            widget.masterMinWidth,
            available - widget.detailMinWidth,
          );

          final masterShare = _masterShare;

          final masterWidth = masterShare == null
              ? (available *
                      widget.masterFlex /
                      (widget.masterFlex + widget.detailFlex))
                  .clamp(widget.masterMinWidth, available / 2)
              : (available * masterShare)
                  .clamp(widget.masterMinWidth, maxMasterWidth);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(width: masterWidth, child: master),
              // Drag to resize the list; double-click for its default width.
              MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // Measured from where the button went down, so the divider
                  // stays under the pointer: no jump once the drag is
                  // recognised, and no movement lost between frames.
                  dragStartBehavior: DragStartBehavior.down,
                  onHorizontalDragStart: (details) {
                    _dragStartX = details.globalPosition.dx;
                    _dragStartWidth = masterWidth;
                  },
                  onHorizontalDragUpdate: (details) => setState(() {
                    _masterShare = ((_dragStartWidth +
                                    details.globalPosition.dx -
                                    _dragStartX)
                                .clamp(widget.masterMinWidth, maxMasterWidth)) /
                        available;
                  }),
                  onHorizontalDragEnd: (_) => _saveMasterShare(),
                  onDoubleTap: () {
                    setState(() => _masterShare = null);

                    _saveMasterShare();
                  },
                  child: Container(
                    width: _dividerWidth,
                    color: VardhmanColors.darkGrey,
                    alignment: Alignment.center,
                    child: Container(
                      width: 2,
                      height: 32,
                      decoration: BoxDecoration(
                        color: VardhmanColors.dividerGrey,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
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
