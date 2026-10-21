import 'package:flutter/material.dart';

/// Gives [child] at least [minWidth], scrolling sideways when the space is
/// narrower, so tables whose columns are sized as shares of the width stay
/// readable on a phone. Wrap the header and the rows of a table together, so
/// they scroll as one.
class MinWidthScroll extends StatefulWidget {
  const MinWidthScroll({
    super.key,
    required this.minWidth,
    required this.child,
  });

  final double minWidth;

  final Widget child;

  @override
  State<MinWidthScroll> createState() => _MinWidthScrollState();
}

class _MinWidthScrollState extends State<MinWidthScroll> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= widget.minWidth) {
          return widget.child;
        }

        return Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: widget.minWidth,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}
