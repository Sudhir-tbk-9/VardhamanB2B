import 'package:flutter/widgets.dart';

/// Closes the [DropdownSearch] menu it is in when the window is resized
/// (e.g. browser DevTools opened, window dragged smaller). Use in the popup's
/// `containerBuilder`.
///
/// dropdown_search 6 places its menu once, when it opens, against the window
/// size of that moment. Laid out again in a smaller window that position
/// leaves the menu a negative width, an assertion that then breaks every
/// following frame of the app. The menu is removed in [didChangeMetrics],
/// before the frame in the new size is laid out; a pop would keep it on
/// screen, and laid out, for its closing animation.
class ClosePopupOnResize extends StatefulWidget {
  const ClosePopupOnResize({super.key, required this.child});

  final Widget child;

  @override
  State<ClosePopupOnResize> createState() => _ClosePopupOnResizeState();
}

class _ClosePopupOnResizeState extends State<ClosePopupOnResize>
    with WidgetsBindingObserver {
  Size? _openedAt;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _openedAt ??= View.of(context).physicalSize;
  }

  @override
  void didChangeMetrics() {
    if (!mounted || View.of(context).physicalSize == _openedAt) {
      return;
    }

    final route = ModalRoute.of(context);

    if (route != null && route.isActive) {
      route.navigator?.removeRoute(route);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
