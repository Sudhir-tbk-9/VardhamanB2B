import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/common/vardhman_loader.dart';
import 'package:vardhman_b2b/login/login_controller.dart';
import 'package:vardhman_b2b/login/login_view.dart';
import 'package:video_player/video_player.dart';

class _FakeLoginController extends GetxController implements LoginController {
  @override
  final rxLoginState = LoginState.unknown.obs;

  @override
  final rxUserId = ''.obs;

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
  testWidgets(
      'after a logout a loader shows until Password, and Password keeps the '
      'cursor while typing', (tester) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = _FakeLoginController();
    Get.put<LoginController>(controller);
    addTearDown(Get.reset);

    // Like the router's login gate (app_router.dart, _LoginGate).
    await tester.pumpWidget(
      MaterialApp(
        home: Obx(() => switch (controller.rxLoginState.value) {
              LoginState.unknown => const Scaffold(
                  body: Center(
                    child: VardhmanLoader(message: 'Please wait...'),
                  ),
                ),
              _ => LoginView(),
            }),
      ),
    );
    await tester.pump();

    // Looking up the saved user: no User ID step meanwhile.
    expect(find.byType(VardhmanLoader), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    // The saved user is found.
    controller.rxUserId.value = 'CUST01';
    controller.rxLoginState.value = LoginState.password;
    await tester.pump();
    await tester.pump();

    final passwordField = find.byType(TextField).last;

    EditableText passwordEditable() => tester.widget<EditableText>(
          find.descendant(
            of: passwordField,
            matching: find.byType(EditableText),
          ),
        );

    expect(passwordEditable().focusNode.hasFocus, isTrue);

    // Typing one character after another stays in Password.
    tester.testTextInput.enterText('a');
    await tester.pump();
    expect(passwordEditable().focusNode.hasFocus, isTrue);

    tester.testTextInput.enterText('ab');
    await tester.pump();
    tester.testTextInput.enterText('abc');
    await tester.pump();

    expect(passwordEditable().focusNode.hasFocus, isTrue);
    expect(controller.rxPassword.value, 'abc');
  });
}
