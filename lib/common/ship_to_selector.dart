import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/api/user_address.dart';
import 'package:vardhman_b2b/app/theme_variants.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/user/user_controller.dart';

/// One-line "Deliver to" bar shown under the order entry header, with a
/// full-width dropdown of the Ship-To options. Options are the Sold-To
/// address (ORCH550116_Get_SoldTo_Address) plus the delivery addresses
/// maintained in the JDE customer master (ORCH550101K_GetDeliveryAddress);
/// the selection is what order submit sends as `ShipTo`.
class ShipToBar extends StatelessWidget {
  const ShipToBar({super.key});

  /// "Name · street · City, State (number)".
  String _label(UserAddress address) {
    final street = [
      address.addressLine1,
      address.addressLine2,
      address.addressLine3,
      address.addressLine4,
    ].map((line) => line.trim()).where((line) => line.isNotEmpty).join(', ');

    final place = [address.city, address.state]
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(', ');

    final number = address.deliveryAddressNumber == 0
        ? 'Sold-To'
        : address.deliveryAddressNumber.toString();

    final parts = [address.alphaName.trim(), street, place]
        .where((part) => part.isNotEmpty)
        .join(' · ');

    return '$parts ($number)';
  }

  @override
  Widget build(BuildContext context) {
    final UserController userController = Get.find(tag: 'userController');

    return Obx(
      () {
        final addresses = userController.rxDeliveryAddresses.toList();

        final selected = userController.rxDeliveryAddress.value;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          // A light wash of the theme's primary gradient; the dark text
          // stays readable on it.
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: ThemeVariants.current.primaryGradient
                  .map((color) =>
                      Color.alphaBlend(color.withAlpha(36), Colors.white))
                  .toList(),
            ),
            border: Border(
              bottom: BorderSide(color: VardhmanColors.dividerGrey),
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.local_shipping_outlined,
                size: 18,
                color: VardhmanColors.red,
              ),
              const SizedBox(width: 8),
              Text(
                'Deliver to:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: VardhmanColors.darkGrey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: VardhmanColors.darkGrey,
                              ),
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
              ),
            ],
          ),
        );
      },
    );
  }
}
