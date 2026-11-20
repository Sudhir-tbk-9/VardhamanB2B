import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';
import 'package:vardhman_b2b/common/primary_button.dart';
import 'package:vardhman_b2b/common/secondary_button.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/drift/database.dart';
import 'package:vardhman_b2b/user/user_controller.dart';

/// Deletes the logged in customer's drafts from this browser: all of them,
/// those of one [orderType] (BK, DT, or LD for Labdip and Sampling both),
/// or the one draft [orderNumber]. Returns how many orders were cleared.
Future<int> deleteDrafts({String? orderType, int? orderNumber}) async {
  final soldTo = Get.find<UserController>(tag: 'userController')
      .rxUserDetail
      .value
      .soldToNumber;

  final table = Get.find<Database>().managers.draftTable;

  var query = table.filter((f) => f.soldTo.equals(soldTo));

  if (orderType != null) {
    query = query.filter((f) => f.orderType.equals(orderType));
  }

  if (orderNumber != null) {
    query = query.filter((f) => f.orderNumber.equals(orderNumber));
  }

  final orderNumbers = (await query.get())
      .map((line) => (line.orderType, line.orderNumber))
      .toSet();

  await query.delete();

  debugPrint(
    '[DRAFTS] Cleared ${orderNumbers.length} draft order(s) of sold-to '
    '$soldTo${orderType == null ? '' : ', type $orderType'}'
    '${orderNumber == null ? '' : ', order $orderNumber'}: '
    '${orderNumbers.map((o) => '${o.$1} #${o.$2}').join(', ')}',
  );

  return orderNumbers.length;
}

/// Asks before drafts are deleted: they are only in this browser and cannot
/// be brought back. True for Clear.
Future<bool> confirmClearDrafts({
  required String title,
  required String message,
}) async {
  final confirmed = await Get.dialog<bool>(
    AlertDialog(
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 420,
        child: Text(
          '$message This cannot be undone.',
          style: TextStyle(fontSize: 13, color: VardhmanColors.darkGrey),
        ),
      ),
      actions: [
        SecondaryButton(
          text: 'Cancel',
          onPressed: () async => Get.back(result: false),
        ),
        PrimaryButton(
          wait: false,
          text: 'Clear',
          iconData: Icons.delete_outline,
          onPressed: () async => Get.back(result: true),
        ),
      ],
    ),
  );

  return confirmed == true;
}

/// "Clear drafts" button: asks first, deletes the drafts [deleteDrafts]
/// picks with [orderType] / [orderNumber], says how many went, then calls
/// [onCleared] (e.g. to close the order screen).
class ClearDraftsButton extends StatelessWidget {
  final String text;

  final String? orderType;

  final int? orderNumber;

  /// Title and text of the confirmation.
  final String confirmTitle;

  final String confirmMessage;

  final VoidCallback? onCleared;

  const ClearDraftsButton({
    super.key,
    this.text = 'Clear Drafts',
    this.orderType,
    this.orderNumber,
    required this.confirmTitle,
    required this.confirmMessage,
    this.onCleared,
  });

  @override
  Widget build(BuildContext context) {
    return SecondaryButton(
      text: text,
      iconData: Icons.delete_sweep_outlined,
      tooltip: confirmTitle,
      onPressed: () async {
        if (!await confirmClearDrafts(
          title: confirmTitle,
          message: confirmMessage,
        )) {
          return;
        }

        final count = await deleteDrafts(
          orderType: orderType,
          orderNumber: orderNumber,
        );

        toastification.show(
          autoCloseDuration: const Duration(seconds: 4),
          primaryColor: VardhmanColors.green,
          title: Text(
            count == 1 ? '1 draft cleared' : '$count drafts cleared',
          ),
        );

        onCleared?.call();
      },
    );
  }
}
