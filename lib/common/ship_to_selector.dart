import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/api/user_address.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/user/user_controller.dart';

/// Ship-To picker for order entry. Options are the Sold-To address
/// (ORCH550116_Get_SoldTo_Address) plus the delivery addresses maintained in
/// the JDE customer master (ORCH550101K_GetDeliveryAddress); the selection is
/// what order submit sends as `ShipTo`.
class ShipToSelector extends StatelessWidget {
  const ShipToSelector({super.key});

  String _label(UserAddress address) {
    final place = [address.city, address.state]
        .where((part) => part.trim().isNotEmpty)
        .join(', ');

    final number = address.deliveryAddressNumber == 0
        ? 'Sold-To'
        : address.deliveryAddressNumber.toString();

    return '${address.alphaName.trim()}${place.isEmpty ? '' : ' - $place'} ($number)';
  }

  @override
  Widget build(BuildContext context) {
    final UserController userController = Get.find(tag: 'userController');

    return Obx(
      () {
        final addresses = userController.rxDeliveryAddresses.toList();

        final selected = userController.rxDeliveryAddress.value;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ship To: ',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: DropdownButton<UserAddress>(
                isExpanded: true,
                isDense: true,
                value: addresses.contains(selected) ? selected : null,
                hint: Text(
                  'No Ship-To address found',
                  style: TextStyle(fontSize: 13, color: VardhmanColors.red),
                ),
                items: addresses
                    .map(
                      (address) => DropdownMenuItem<UserAddress>(
                        value: address,
                        child: Text(
                          _label(address),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: addresses.length < 2
                    ? null
                    : (address) {
                        if (address != null) {
                          userController.selectDeliveryAddress(address);
                        }
                      },
              ),
            ),
          ],
        );
      },
    );
  }
}
