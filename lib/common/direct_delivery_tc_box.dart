import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/orders/direct_delivery_tc.dart';

/// The "Tick if TC Required" box (direct delivery) of the DTM and Bulk forms,
/// sized to sit beside a form field (aligned with its input box). Show it
/// only while [DirectDeliveryTc.offersTc].
class DirectDeliveryTcBox extends StatelessWidget {
  final DirectDeliveryTc controller;

  const DirectDeliveryTcBox({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // A TC order: every line is TC, the box cannot be unticked.
      final locked = controller.isTcLocked;

      return Tooltip(
        message: locked ? 'TC Required order: every line is TC Required' : '',
        child: Padding(
        // Lines up with the 36 px box of the field beside it.
        padding: const EdgeInsets.all(4),
        child: SizedBox(
          height: 36,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: locked
                ? null
                : () => controller.rxTcRequired.value =
                    !controller.rxTcRequired.value,
            child: Row(
              children: [
                Checkbox(
                  value: locked || controller.rxTcRequired.value,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: locked
                      ? null
                      : (value) =>
                          controller.rxTcRequired.value = value ?? false,
                ),
                Flexible(
                  child: Text(
                    'Tick if TC Required',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: VardhmanColors.darkGrey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      );
    });
  }
}
