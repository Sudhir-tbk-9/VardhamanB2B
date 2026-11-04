import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/login/login_controller.dart';
import 'package:vardhman_b2b/login/login_view.dart';
import 'package:video_player/video_player.dart';

class _FakeLoginController extends GetxController implements LoginController {
  @override
  final rxLoginState = LoginState.loggedOut.obs;

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
  Future<void> validateUser() async {
    rxLoginState.value = LoginState.otp;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets('User ID can be typed again after cancelling the OTP step',
      (tester) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = _FakeLoginController();
    Get.put<LoginController>(controller);
    addTearDown(Get.reset);

    // Like the router's login gate: a new LoginView on every step.
    await tester.pumpWidget(
      MaterialApp(
        home: Obx(() => switch (controller.rxLoginState.value) {
              _ => LoginView(),
            }),
      ),
    );
    await tester.pump();

    final userIdField = find.byType(TextField).first;

    await tester.enterText(userIdField, 'CUST01');
    await tester.pump();
    expect(controller.rxUserId.value, 'CUST01');

    // Enter sends the OTP, as on the real screen.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump();

    expect(controller.rxLoginState.value, LoginState.loggedOut);

    // The cursor is back in User ID, and typing reaches it.
    final editable = tester.widget<EditableText>(
      find.descendant(of: userIdField, matching: find.byType(EditableText)),
    );
    expect(editable.focusNode.hasFocus, isTrue);

    tester.testTextInput.enterText('CUST02');
    await tester.pump();
    expect(controller.rxUserId.value, 'CUST02');
  });
}
