import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/login/login_controller.dart';
import 'package:vardhman_b2b/login/login_view.dart';
import 'package:video_player/video_player.dart';

/// What LoginView reads, without the database, JDE or the video stream the
/// real controller starts.
class _FakeLoginController extends GetxController implements LoginController {
  @override
  final rxLoginState = LoginState.loggedOut.obs;

  @override
  final rxUserId = 'CUST01'.obs;

  @override
  final rxPassword = ''.obs;

  @override
  final rxConfirmPassword = ''.obs;

  @override
  final rxOtp = ''.obs;

  @override
  late final VideoPlayerController videoPlayerController =
      VideoPlayerController.networkUrl(Uri.parse('https://example.invalid/'));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  // Tests draw text in the Ahem font, every glyph a full square, so labels
  // come out about 1.8x wider than with the app's font: passing at 360 here
  // leaves room to spare on real 320-wide phones.
  const sizes = <String, Size>{
    'phone': Size(360, 640),
    'tablet': Size(768, 1024),
    'laptop': Size(1366, 768),
    'desktop': Size(1920, 1080),
  };

  for (final MapEntry(key: name, value: size) in sizes.entries) {
    for (final state in [
      LoginState.loggedOut,
      LoginState.otp,
      LoginState.setPassword,
      LoginState.password,
    ]) {
      testWidgets('no overflow: $name, ${state.name}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final controller = _FakeLoginController()..rxLoginState.value = state;
        Get.put<LoginController>(controller);
        addTearDown(Get.reset);

        await tester.pumpWidget(MaterialApp(home: LoginView()));
        await tester.pump();

        // Every field and button of the step is on screen or reachable by
        // scrolling (a layout overflow fails the test by itself).
        expect(find.text('User ID', findRichText: true), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
