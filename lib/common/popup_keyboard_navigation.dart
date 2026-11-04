import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Arrow keys move a highlight through a [DropdownSearch] popup's options and
/// Enter picks the highlighted one (the first when none is highlighted).
/// Use as the popup's `containerBuilder`, and wrap each item from
/// `itemBuilder` in [PopupKeyboardHighlight]. dropdown_search 6 has no
/// keyboard navigation of its own.
class PopupKeyboardNavigation<T> extends StatefulWidget {
  const PopupKeyboardNavigation({
    super.key,
    required this.autofocus,
    required this.child,
  });

  /// Take focus when the popup opens; for popups whose search box does not.
  final bool autofocus;

  final Widget child;

  @override
  State<PopupKeyboardNavigation<T>> createState() =>
      _PopupKeyboardNavigationState<T>();
}

class _PopupKeyboardNavigationState<T>
    extends State<PopupKeyboardNavigation<T>> {
  final highlighted = ValueNotifier<T?>(null);

  /// Set by an arrow key, so the highlighted item scrolls into view.
  bool movedDown = true;

  DropdownSearchPopupState<T>? get _popup =>
      context.findAncestorStateOfType<DropdownSearchPopupState<T>>();

  List<T> get _items => _popup?.getLoadedItems ?? [];

  /// The highlighted item, or the first one while none is highlighted (or
  /// the highlighted one was filtered out by the search).
  T? get current {
    final items = _items;

    final item = highlighted.value;

    if (item != null && items.contains(item)) {
      return item;
    }

    return items.isEmpty ? null : items.first;
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final items = _items;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      if (items.isEmpty) {
        return KeyEventResult.handled;
      }

      final item = highlighted.value;

      final index = item == null ? -1 : items.indexOf(item);

      movedDown = key == LogicalKeyboardKey.arrowDown;

      highlighted.value = items[movedDown
          ? (index + 1).clamp(0, items.length - 1)
          : (index - 1).clamp(0, items.length - 1)];

      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      final popup = _popup;

      final item = current;

      if (popup == null || item == null) {
        return KeyEventResult.ignored;
      }

      // As a tap on the item does.
      popup.closePopup();

      popup.widget.onChanged?.call([item]);

      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    highlighted.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onKeyEvent: _onKeyEvent,
      child: _PopupKeyboardScope<T>(state: this, child: widget.child),
    );
  }
}

class _PopupKeyboardScope<T> extends InheritedWidget {
  const _PopupKeyboardScope({required this.state, required super.child});

  final _PopupKeyboardNavigationState<T> state;

  @override
  bool updateShouldNotify(_PopupKeyboardScope<T> oldWidget) =>
      state != oldWidget.state;
}

/// Tints [item] while it is the keyboard highlight, and keeps it in view.
class PopupKeyboardHighlight<T> extends StatelessWidget {
  const PopupKeyboardHighlight({
    super.key,
    required this.item,
    required this.color,
    required this.child,
  });

  final T item;

  final Color color;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final state = context
        .dependOnInheritedWidgetOfExactType<_PopupKeyboardScope<T>>()
        ?.state;

    if (state == null) {
      return child;
    }

    return ValueListenableBuilder<T?>(
      valueListenable: state.highlighted,
      builder: (context, highlighted, child) {
        final isHighlighted = state.current == item;

        if (isHighlighted && highlighted == item) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Scrollable.ensureVisible(
                context,
                alignmentPolicy: state.movedDown
                    ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
                    : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
              );
            }
          });
        }

        return ColoredBox(
          color: isHighlighted ? color : Colors.transparent,
          child: child,
        );
      },
      child: child,
    );
  }
}
