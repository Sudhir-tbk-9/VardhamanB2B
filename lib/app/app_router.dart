import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:vardhman_b2b/common/vardhman_loader.dart';
import 'package:vardhman_b2b/home/home_controller.dart';
import 'package:vardhman_b2b/home/home_scaffold.dart';
import 'package:vardhman_b2b/login/login_controller.dart';
import 'package:vardhman_b2b/login/login_view.dart';

/// URL of each home tab, in nav rail order: 0–3 orders, 4–5 payments (see
/// NavRail). With Flutter web's default hash strategy these show as
/// `…/#/open`, so the server only ever sees the app root and the gateway's
/// `POST /vytldev/` handling is unchanged.
const homeTabPaths = <String>[
  '/sampling',
  '/labdip',
  '/dtm',
  '/bulk',
  '/open',
  '/paid',
];

const _loginPath = '/login';

/// Nav rail index for [path], or null when it is not a home tab.
int? homeTabIndexOf(String path) {
  final index = homeTabPaths.indexOf(path);

  return index == -1 ? null : index;
}

/// The app's routes. The URL decides which home tab is shown, so a refresh,
/// the browser back / forward buttons and coming back from an external link
/// keep the tab. The login flow itself still runs on
/// [LoginController.rxLoginState]: the router only sends the user to
/// `/login` until it is [LoginState.loggedIn], and then on to the tab they
/// asked for.
///
/// Lazily created on first use, which is in [App.build], after main() has
/// registered [LoginController].
final appRouter = GoRouter(
  // Shared with GetX so Get.dialog, Get.back and Get.showSnackbar use the
  // router's navigator.
  navigatorKey: Get.key,
  initialLocation: '/',
  refreshListenable: _RxListenable(Get.find<LoginController>().rxLoginState),
  redirect: _redirect,
  routes: <RouteBase>[
    GoRoute(
      path: _loginPath,
      pageBuilder: (context, state) => const NoTransitionPage(
        child: _LoginGate(),
      ),
    ),
    GoRoute(
      path: '/:tab',
      // One page key for every tab, so switching tabs updates the same
      // HomeScaffold (and its kept-alive tabs) instead of pushing a new page.
      pageBuilder: (context, state) => NoTransitionPage(
        key: const ValueKey('home'),
        child: HomeScaffold(
          tabIndex: homeTabIndexOf(state.matchedLocation) ?? 0,
        ),
      ),
    ),
  ],
);

String? _redirect(BuildContext context, GoRouterState state) {
  final path = state.uri.path;

  final isLoggedIn =
      Get.find<LoginController>().rxLoginState.value == LoginState.loggedIn;

  if (!isLoggedIn) {
    if (path == _loginPath) {
      return null;
    }

    // Remember the tab so it opens once the user has logged in again.
    return Uri(
      path: _loginPath,
      queryParameters: homeTabIndexOf(path) == null ? null : {'from': path},
    ).toString();
  }

  if (homeTabIndexOf(path) != null) {
    return null;
  }

  // Logged in on /login, the bare app URL (e.g. the gateway's return) or an
  // unknown path: go to the tab from the URL, else the one the session was
  // restored to (payment return marker), else Sampling.
  final from = state.uri.queryParameters['from'];

  if (from != null && homeTabIndexOf(from) != null) {
    return from;
  }

  final navRailIndex = Get.isRegistered<HomeController>()
      ? Get.find<HomeController>().rxNavRailIndex.value
      : 0;

  return homeTabPaths[navRailIndex];
}

/// The login flow on `/login`, switched by [LoginController.rxLoginState]
/// exactly as `home:` used to be.
class _LoginGate extends StatelessWidget {
  const _LoginGate();

  @override
  Widget build(BuildContext context) {
    final loginController = Get.find<LoginController>();

    return Obx(
      () => switch (loginController.rxLoginState.value) {
        LoginState.resuming || LoginState.loggedIn => const Scaffold(
            body: Center(
              child: VardhmanLoader(message: 'Taking you back...'),
            ),
          ),
        _ => LoginView(),
      },
    );
  }
}

/// Lets the router re-run [_redirect] whenever a GetX observable changes.
class _RxListenable extends ChangeNotifier {
  _RxListenable(RxInterface<Object?> rx) {
    _subscription = rx.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();

    super.dispose();
  }
}
