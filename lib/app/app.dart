import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';
import 'package:vardhman_b2b/app/app_router.dart';
import 'package:vardhman_b2b/app/theme_variants.dart';
import 'package:vardhman_b2b/common/vardhman_loader.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();

    return ToastificationWrapper(
      child: GetMaterialApp.router(
        // Shown as the browser tab title; without it the tab shows the URL.
        title: 'Vardhman B2B Portal',
        routerDelegate: appRouter.routerDelegate,
        routeInformationParser: appRouter.routeInformationParser,
        routeInformationProvider: appRouter.routeInformationProvider,
        backButtonDispatcher: appRouter.backButtonDispatcher,
        theme: themeController.themeData,
        // The theme is applied here rather than by rebuilding GetMaterialApp:
        // MaterialApp animates theme changes by interpolating the whole
        // ThemeData every frame for 200 ms, which made switching stutter.
        // Routes and dialogs sit below this builder, so they follow it too.
        builder: (context, child) => Obx(
          () => Theme(
            data: themeController.themeData,
            child: Stack(
              children: [
                if (child != null) child,
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ApiActivityBar(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
