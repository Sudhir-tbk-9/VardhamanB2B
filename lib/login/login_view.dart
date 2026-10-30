import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/common/breakpoints.dart';
import 'package:vardhman_b2b/common/new_order_text_field.dart';
import 'package:vardhman_b2b/common/primary_button.dart';
import 'package:vardhman_b2b/common/secondary_button.dart';
import 'package:vardhman_b2b/common/upper_case_text_formatter.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/login/login_controller.dart';
import 'package:video_player/video_player.dart';

/// Whether an Enter in a field is running its button's action, so a second
/// Enter (or a held key) does not run it again meanwhile.
bool _isSubmitting = false;

/// Runs [action] for Enter in a field, as the field's button would. [action]
/// is null while that button is disabled.
Future<void> _submit(Future<void> Function()? action) async {
  if (action == null || _isSubmitting) {
    return;
  }

  _isSubmitting = true;

  final loginController = Get.find<LoginController>();

  final loginState = loginController.rxLoginState.value;

  // Let go of the keyboard first, as clicking the button does. The next step
  // can disable this field (User ID during OTP), and on the web a field
  // disabled while it has the keyboard leaves its browser input read-only:
  // back on User ID after Cancel, nothing typed reached it.
  final focusNode = FocusManager.instance.primaryFocus;

  focusNode?.unfocus();

  try {
    await action();
  } finally {
    _isSubmitting = false;

    // Still on the same step (wrong OTP, unknown user): back to the field.
    // A new step puts the cursor in its own field.
    if (loginController.rxLoginState.value == loginState) {
      focusNode?.requestFocus();
    }
  }
}

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  // Kept for the whole login flow: the router builds a new LoginView on
  // every step, and focus nodes made afresh each time (while the old field
  // still held focus) left User ID untypeable on the web after going back
  // from the OTP step.
  final FocusNode _userIdFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _otpFocusNode = FocusNode();
  final FocusNode _newPasswordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  /// The step whose field was last given the cursor.
  LoginState? _focusedLoginState;

  @override
  void dispose() {
    _userIdFocusNode.dispose();
    _passwordFocusNode.dispose();
    _otpFocusNode.dispose();
    _newPasswordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();

    super.dispose();
  }

  /// Gives [loginState]'s field the cursor when the step changes, so the user
  /// can type and press Enter straight away. Done after the frame, once the
  /// field is built and enabled for the step (User ID is disabled during
  /// the others).
  void _focusFieldOf(LoginState loginState) {
    if (loginState == _focusedLoginState) {
      return;
    }

    _focusedLoginState = loginState;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final focusNode = switch (loginState) {
        LoginState.password => _passwordFocusNode,
        LoginState.otp => _otpFocusNode,
        LoginState.setPassword => _newPasswordFocusNode,
        _ => _userIdFocusNode,
      };

      focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final loginController = Get.find<LoginController>();

    // Phone sized: smaller header, and the page scrolls (see below).
    final isCompact = context.isCompact;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Obx(
        () {
          _focusFieldOf(loginController.rxLoginState.value);

          // Built in here: they read the observables this Obx tracks.
          // Sized from the controller, which loads after the screen shows.
          final video = RepaintBoundary(
            child: ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: loginController.videoPlayerController,
              builder: (context, video, child) => FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: video.size.width,
                  height: video.size.height,
                  child: child,
                ),
              ),
              child: VideoPlayer(loginController.videoPlayerController),
            ),
          );

          final header = Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: double.infinity,
                color: Colors.white,
                height: 100,
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (!isCompact)
                    const SizedBox(
                      width: 140,
                    ),
                  Container(
                    margin: EdgeInsets.only(top: 20),
                    child: Image.asset(
                      'assets/digital-nws.png',
                      height: isCompact ? 40 : 60,
                    ),
                  ),
                  Image.asset(
                    'assets/50_years.png',
                    height: isCompact ? 90 : 140,
                    width: isCompact ? 90 : 140,
                  ),
                ],
              ),
            ],
          );

          // Each button's action, null while the button is disabled. Enter in
          // the step's field runs the same one.
          final sendOtp = loginController.rxUserId.value.isEmpty
              ? null
              : loginController.validateUser;

          final logIn = loginController.rxPassword.value.isEmpty
              ? null
              : loginController.validatePassword;

          final verifyOtp = loginController.rxOtp.value.isEmpty
              ? null
              : loginController.validateOtp;

          final setPassword = loginController.rxPassword.value.trim().isEmpty ||
                  loginController.rxConfirmPassword.value !=
                      loginController.rxPassword.value
              ? null
              : loginController.setPassword;

          final card = Container(
            // margin: EdgeInsets.all(16),
            constraints: const BoxConstraints(maxWidth: 600),
            // padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
              color: Colors.black26,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(
                  height: 16,
                ),
                const Text(
                  'DIGITAL WORLD',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 16,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: const Text(
                    'Welcome to our Portal which is for Buyers looking to place & track their Orders with ease, comfort and convenience, with a few clicks.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 16,
                ),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isCompact ? 16 : 32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.zero,
                      bottom: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    children: <Widget>[
                      // TextField(
                      //   controller:
                      //       loginController.userIdTextEditingController,
                      //   decoration: InputDecoration(
                      //     labelText: 'User ID',
                      //     border: OutlineInputBorder(),
                      //   ),
                      // ),
                      Wrap(
                        alignment: WrapAlignment.center,
                        runSpacing: 16,
                        children: [
                          SizedBox(
                            width: 150,
                            child: NewOrderTextField(
                              focusNode: _userIdFocusNode,
                              inputFormatters: [UpperCaseTextFormatter()],
                              isEnabled: loginController.rxLoginState.value ==
                                  LoginState.loggedOut,
                              labelText: 'User ID',
                              rxString: loginController.rxUserId,
                              onSubmitted: () => _submit(sendOtp),
                            ),
                          ),
                          if (loginController.rxLoginState.value ==
                              LoginState.password) ...[
                            SizedBox(width: 16),
                            SizedBox(
                              width: 150,
                              child: NewOrderTextField(
                                focusNode: _passwordFocusNode,
                                obscureText: true,
                                labelText: 'Password',
                                rxString: loginController.rxPassword,
                                onSubmitted: () => _submit(logIn),
                              ),
                            ),
                          ],
                          if (loginController.rxLoginState.value ==
                              LoginState.otp) ...[
                            SizedBox(width: 16),
                            SizedBox(
                              width: 150,
                              child: NewOrderTextField(
                                focusNode: _otpFocusNode,
                                labelText: 'OTP',
                                rxString: loginController.rxOtp,
                                onSubmitted: () => _submit(verifyOtp),
                              ),
                            ),
                          ],
                          if (loginController.rxLoginState.value ==
                              LoginState.setPassword) ...[
                            SizedBox(width: 16),
                            SizedBox(
                              width: 150,
                              child: NewOrderTextField(
                                focusNode: _newPasswordFocusNode,
                                obscureText: true,
                                labelText: 'New Password',
                                rxString: loginController.rxPassword,
                                // On to Confirm Password, which is enabled
                                // once a new password is typed.
                                onSubmitted: () {
                                  if (loginController.rxPassword.isNotEmpty) {
                                    _confirmPasswordFocusNode.requestFocus();
                                  }
                                },
                              ),
                            ),
                            SizedBox(width: 16),
                            SizedBox(
                              width: 150,
                              child: NewOrderTextField(
                                focusNode: _confirmPasswordFocusNode,
                                obscureText: true,
                                labelText: 'Confirm Password',
                                isEnabled:
                                    loginController.rxPassword.isNotEmpty,
                                rxString: loginController.rxConfirmPassword,
                                onSubmitted: () => _submit(setPassword),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(
                        height: 32,
                      ),
                      if (loginController.rxLoginState.value ==
                          LoginState.loggedOut)
                        PrimaryButton(
                          iconData: Icons.login_outlined,
                          text: 'Send OTP',
                          onPressed: sendOtp,
                        ),
                      if (loginController.rxLoginState.value ==
                          LoginState.password)
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          runSpacing: 12,
                          children: [
                            SecondaryButton(
                              text: 'Change User/Password',
                              wait: false,
                              onPressed: loginController.forgotPassword,
                            ),
                            SizedBox(width: 32),
                            PrimaryButton(
                              iconData: Icons.login_outlined,
                              text: 'Login',
                              onPressed: logIn,
                            ),
                          ],
                        ),
                      if (loginController.rxLoginState.value == LoginState.otp)
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          runSpacing: 12,
                          children: [
                            SecondaryButton(
                              text: 'Cancel',
                              wait: false,
                              onPressed: () async {
                                loginController.rxLoginState.value =
                                    LoginState.loggedOut;
                                loginController.rxUserId.value = '';
                                loginController.rxOtp.value = '';
                              },
                            ),
                            SizedBox(width: 32),
                            PrimaryButton(
                              iconData: Icons.login_outlined,
                              text: 'Verify OTP',
                              onPressed: verifyOtp,
                            ),
                          ],
                        ),
                      if (loginController.rxLoginState.value ==
                          LoginState.setPassword)
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          runSpacing: 12,
                          children: [
                            SecondaryButton(
                              text: 'Cancel',
                              wait: false,
                              onPressed: () async {
                                loginController.rxLoginState.value =
                                    LoginState.loggedOut;
                                loginController.rxUserId.value = '';
                                loginController.rxOtp.value = '';
                              },
                            ),
                            SizedBox(width: 32),
                            PrimaryButton(
                              iconData: Icons.login_outlined,
                              text: 'Set Password',
                              onPressed: setPassword,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );

          final footer = Container(
            padding: EdgeInsets.all(16),
            color: Colors.black,
            child: DefaultTextStyle(
              style: TextStyle(
                color: Colors.white,
              ),
              child: Flex(
                direction: isCompact ? Axis.vertical : Axis.horizontal,
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: isCompact
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                spacing: isCompact ? 8 : 0,
                children: <Widget>[
                  _FooterBlock(
                    isTight: false,
                    isCompact: isCompact,
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.location_on,
                          color: VardhmanColors.red,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: const Text(
                            'Vardhman Yarns & Threads Ltd, Central Marketing Office, 1st Floor, Palm Court Sector 16, M.G.Road Gurugram - 122001',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isCompact)
                    Flexible(
                      flex: 1,
                      child: SizedBox(
                        width: 20,
                      ),
                    ),
                  _FooterBlock(
                    isTight: true,
                    isCompact: isCompact,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.phone,
                              color: VardhmanColors.red,
                            ),
                            SizedBox(width: 8),
                            // Flexible: wraps instead of overflowing on a
                            // narrow window.
                            const Flexible(
                              child: Text(
                                '+91 124-4981600 , +91 124-4981601',
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          children: <Widget>[
                            Icon(
                              Icons.email,
                              color: VardhmanColors.red,
                            ),
                            SizedBox(width: 8),
                            const Flexible(
                              child: Text(
                                'info@vardhmanthreads.in',
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  _FooterBlock(
                    isTight: false,
                    isCompact: isCompact,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            'Designed and Developed by\nAUSM INFOTECH Pvt. Ltd.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );

          return SafeArea(
            child: isCompact
                // Phone: header, card and footer scroll as one column over the
                // video, so they never overlap.
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      video,
                      LayoutBuilder(
                        builder: (context, constraints) =>
                            SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                header,
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: card,
                                ),
                                footer,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      video,
                      Align(alignment: Alignment.topCenter, child: header),
                      Align(alignment: Alignment.center, child: card),
                      Align(alignment: Alignment.bottomCenter, child: footer),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

/// One block of the login footer: a share of the row on a larger window
/// ([Expanded] when [isTight], else [Flexible]), a plain child on a phone,
/// where the blocks are stacked.
class _FooterBlock extends StatelessWidget {
  const _FooterBlock({
    required this.isTight,
    required this.isCompact,
    required this.child,
  });

  final bool isTight, isCompact;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return child;
    }

    return isTight ? Expanded(child: child) : Flexible(child: child);
  }
}
