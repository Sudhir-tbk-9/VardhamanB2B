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
              // The arrow follows the selected address, not the bar's far
              // end: the button is only as wide as its text (a
              // DropdownButton is as wide as its longest option).
              Flexible(
                child: _ShipToMenu(
                  addresses: addresses,
                  selected: addresses.contains(selected) ? selected : null,
                  label: _label,
                  onSelected: userController.selectDeliveryAddress,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One row of the Ship-To list. The selected one is tinted with the active
/// theme's primary colour, with a check and its text in that colour.
class _ShipToOption extends StatelessWidget {
  final String text;

  final bool isSelected;

  final Color primary;

  const _ShipToOption({
    required this.text,
    required this.isSelected,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? primary.withAlpha(24) : null,
        border: Border(
          left: BorderSide(
            color: isSelected ? primary : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child:
                isSelected ? Icon(Icons.check, size: 16, color: primary) : null,
          ),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? primary : VardhmanColors.darkGrey,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The selected Ship-To with the dropdown arrow right after it; opens the
/// list of options. Disabled (grey arrow) with fewer than two.
class _ShipToMenu extends StatelessWidget {
  final List<UserAddress> addresses;

  final UserAddress? selected;

  final String Function(UserAddress address) label;

  final ValueChanged<UserAddress> onSelected;

  const _ShipToMenu({
    required this.addresses,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final selected = this.selected;

    final isEnabled = addresses.length > 1;

    final primary = ThemeVariants.current.primary;

    final theme = Theme.of(context);

    // The app theme's highlightColor is the dark accent: the menu filled the
    // initialValue row with it (and flashes it on press), hiding the text.
    // So no initialValue (the selected row is tinted with the active
    // theme's primary colour by _ShipToOption) and light, primary-tinted
    // press colours for this menu.
    return Theme(
      data: theme.copyWith(
        highlightColor: primary.withAlpha(36),
        splashColor: primary.withAlpha(28),
        hoverColor: primary.withAlpha(20),
      ),
      child: PopupMenuButton<UserAddress>(
        enabled: isEnabled,
        tooltip: isEnabled ? 'Change Ship-To' : '',
        position: PopupMenuPosition.under,
        constraints: const BoxConstraints(minWidth: 320, maxWidth: 720),
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        menuPadding: const EdgeInsets.symmetric(vertical: 4),
        onSelected: onSelected,
        itemBuilder: (context) => [
          for (final address in addresses)
            PopupMenuItem<UserAddress>(
              value: address,
              height: 40,
              padding: EdgeInsets.zero,
              child: _ShipToOption(
                text: label(address),
                isSelected: address == selected,
                primary: primary,
              ),
            ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  selected == null
                      ? 'No Ship-To address found'
                      : label(selected),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: selected == null
                        ? VardhmanColors.red
                        : VardhmanColors.darkGrey,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_drop_down,
                size: 22,
                color: isEnabled
                    ? VardhmanColors.darkGrey
                    : VardhmanColors.darkGrey.withAlpha(90),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
