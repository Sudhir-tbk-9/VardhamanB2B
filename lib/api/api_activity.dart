import 'package:get/get.dart';

/// Number of JDE requests currently in flight, maintained by the Dio
/// interceptor in [Api] and shown by the app-wide activity bar.
class ApiActivity {
  static final rxPending = 0.obs;

  static void started() => rxPending.value++;

  static void finished() {
    if (rxPending.value > 0) {
      rxPending.value--;
    }
  }
}
