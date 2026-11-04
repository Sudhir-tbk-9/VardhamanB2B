import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vardhman_b2b/app/app.dart';
import 'package:vardhman_b2b/app/theme_variants.dart';
import 'package:vardhman_b2b/drift/database.dart';
import 'package:vardhman_b2b/login/login_controller.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';

Future<void> main() async {
  // URLs like `/vytldev/open` instead of `/vytldev/#/open`. The server must
  // answer any path under the app with its index.html (docs/NAVIGATION.md,
  // 6.2). A no-op off the web.
  usePathUrlStrategy();

  WidgetsFlutterBinding.ensureInitialized();

  VideoPlayerMediaKit.ensureInitialized(windows: true);

  final sharedPrefs = await SharedPreferences.getInstance();

  Get.put(
    sharedPrefs,
    permanent: true,
  );

  Get.put(
    ThemeController(),
    permanent: true,
  );

  final database = Database();

  Get.put(
    database,
    permanent: true,
  );

  Get.put(
    LoginController(),
    permanent: true,
  );

  runApp(const App());
}
