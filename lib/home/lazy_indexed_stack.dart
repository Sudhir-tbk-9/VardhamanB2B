import 'package:flutter/material.dart';
import 'package:vardhman_b2b/app/theme_variants.dart';

/// An [IndexedStack] that builds each child the first time it is selected and
/// then keeps it alive, so switching back to a tab does not rebuild its views
/// (tables, scroll positions, expanded rows) from scratch.
///
/// Unvisited children are not built at all, so startup only pays for the
/// first tab. Hidden children are not painted, hit-tested or focusable
/// ([IndexedStack] handles that), and their animations are paused here with
/// [TickerMode].
class LazyIndexedStack extends StatefulWidget {
  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  final int index;

  final List<Widget> children;

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  final _visited = <int>{};

  @override
  Widget build(BuildContext context) {
    _visited.add(widget.index);

    return IndexedStack(
      index: widget.index,
      // Children get the same tight constraints they had as the direct child
      // of an Expanded.
      sizing: StackFit.expand,
      children: <Widget>[
        for (var i = 0; i < widget.children.length; i++)
          _visited.contains(i)
              ? TickerMode(
                  enabled: i == widget.index,
                  // A theme switch only rebuilds the shown tab; the others
                  // catch up when selected.
                  child: ThemeRebuildWhenShown(
                    isShown: i == widget.index,
                    child: widget.children[i],
                  ),
                )
              : const SizedBox.shrink(),
      ],
    );
  }
}
