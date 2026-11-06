import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/common/close_popup_on_resize.dart';
import 'package:vardhman_b2b/common/new_order_text_field.dart';
import 'package:vardhman_b2b/common/popup_keyboard_navigation.dart';
import 'package:vardhman_b2b/common/secondary_button.dart';
import 'package:vardhman_b2b/constants.dart';

class CatalogSearchField extends StatelessWidget {
  CatalogSearchField({
    super.key,
    required this.labelText,
    required this.rxString,
    required this.searchList,
    this.isEnabled = true,
    this.isRequired = false,
    this.shouldEnforceList = true,
    this.hasError = false,
    this.isSearchboxEnabled = true,
    this.inputFormatters = const [],
    this.invalidList = const [],
    this.dropdownKey,
    this.onChanged,
  });

  /// Called after the user picks a value or clears the field; not when
  /// [rxString] is set in code.
  final ValueChanged<String>? onChanged;

  /// Lets a controller open this field programmatically.
  final GlobalKey<DropdownSearchState<String>>? dropdownKey;

  final bool isSearchboxEnabled;
  final String labelText;
  final RxString rxString;
  final List<String> searchList;
  final List<String> invalidList;
  final bool isEnabled;
  final bool isRequired;
  final bool shouldEnforceList;
  final bool hasError;
  final List<TextInputFormatter> inputFormatters;

  final noneBorder = OutlineInputBorder(
    borderSide: BorderSide.none,
  );

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: RichText(
                text: TextSpan(
                  text: labelText,
                  style: TextStyle(
                    color: VardhmanColors.darkGrey,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  children: [
                    if (isRequired)
                      TextSpan(
                        text: ' *',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: 4,
            ),
            FieldBox(
              isEnabled: isEnabled,
              hasError: isEnabled && hasError && rxString.value.trim().isEmpty,
              child: Stack(
                children: [
                  Align(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: DropdownSearch<String>(
                            key: dropdownKey,
                            enabled: isEnabled,
                            suffixProps: DropdownSuffixProps(
                              dropdownButtonProps: DropdownButtonProps(
                                isVisible: isEnabled && rxString.value.isEmpty,
                              ),
                            ),
                            decoratorProps: DropDownDecoratorProps(
                              baseStyle: TextStyle(
                                color: VardhmanColors.darkGrey,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                hintText: isEnabled ? 'select' : null,
                                hintStyle: TextStyle(
                                  color: VardhmanColors.darkGrey,
                                  fontSize: 13,
                                ),
                                contentPadding: EdgeInsets.only(left: 8),
                                border: noneBorder,
                                enabledBorder: noneBorder,
                                focusedBorder: noneBorder,
                                disabledBorder: noneBorder,
                              ),
                            ),
                            popupProps: PopupProps.menu(
                              searchFieldProps: TextFieldProps(
                                // Ready to type as soon as the field opens.
                                autofocus: true,
                                inputFormatters: inputFormatters,
                                autocorrect: false,
                                style: TextStyle(
                                  color: VardhmanColors.darkGrey,
                                  fontSize: 13,
                                ),
                              ),
                              showSearchBox: isSearchboxEnabled,
                              fit: FlexFit.loose,
                              searchDelay: Duration(milliseconds: 0),
                              // Arrow keys move through the options, Enter
                              // picks one.
                              containerBuilder: (context, popupWidget) =>
                                  ClosePopupOnResize(
                                child: PopupKeyboardNavigation<String>(
                                  autofocus: !isSearchboxEnabled,
                                  child: popupWidget,
                                ),
                              ),
                              itemBuilder:
                                  (context, item, isDisabled, isSelected) =>
                                      PopupKeyboardHighlight<String>(
                                item: item,
                                color: VardhmanColors.red.withAlpha(40),
                                child: ListTile(
                                  title: Text(
                                    item,
                                    style: TextStyle(
                                      color: VardhmanColors.darkGrey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            items: (searchText, cs) async {
                              final trimmedSearchText = searchText.trim();

                              if (shouldEnforceList ||
                                  invalidList.contains(trimmedSearchText)) {
                                return searchList;
                              } else {
                                return [
                                  if (trimmedSearchText.isNotEmpty &&
                                      !searchList.contains(trimmedSearchText))
                                    trimmedSearchText,
                                  ...searchList
                                ];
                              }
                            },
                            autoValidateMode: AutovalidateMode.disabled,
                            onChanged: (value) {
                              rxString.value = value ?? '';

                              onChanged?.call(rxString.value);
                            },
                            selectedItem:
                                rxString.value.isEmpty ? null : rxString.value,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isEnabled && rxString.value.isNotEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: SecondaryButton(
                        wait: false,
                        iconData: Icons.clear,
                        text: '',
                        onPressed: () async {
                          rxString.value = '';

                          onChanged?.call('');
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
