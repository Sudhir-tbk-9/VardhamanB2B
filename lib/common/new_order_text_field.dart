import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/common/secondary_button.dart';
import 'package:vardhman_b2b/app/theme_variants.dart';
import 'package:vardhman_b2b/constants.dart';

/// The 36 px box of a form field ([NewOrderTextField], CatalogSearchField):
/// a light border, the theme colour while the field has the cursor, the
/// theme's error colour when a required value is missing.
class FieldBox extends StatelessWidget {
  final bool isEnabled;

  final bool hasError;

  final Widget child;

  const FieldBox({
    super.key,
    required this.isEnabled,
    required this.hasError,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final variant = ThemeVariants.current;

    // Focus + Builder: rebuilt when focus enters or leaves the field.
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;

          return Container(
            height: 36,
            // Keeps clear / Choose File buttons off the right border.
            padding: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasError
                    ? variant.error
                    : isFocused
                        ? variant.primary
                        : VardhmanColors.darkGrey.withAlpha(90),
                width: hasError || isFocused ? 1.5 : 1,
              ),
              color: isEnabled
                  ? Colors.white
                  : VardhmanColors.dividerGrey.withAlpha(128),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: variant.primary.withAlpha(40),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
            // Buttons inside the field are compact, clear of its border.
            child: CompactButtons(child: child),
          );
        },
      ),
    );
  }
}

class NewOrderTextField extends StatelessWidget {
  NewOrderTextField({
    super.key,
    required this.labelText,
    this.hintText = '',
    required this.rxString,
    this.isEnabled = true,
    this.minLines = 1,
    this.isRequired = false,
    this.hasError = false,
    this.inputFormatters = const [],
    this.trailingWidget,
    this.maxLength,
    this.obscureText = false,
    this.focusNode,
    this.onSubmitted,
  });

  final String labelText;
  final String hintText;
  final RxString rxString;
  final bool isEnabled;
  final int? minLines;
  final bool isRequired;
  final bool hasError;
  final List<TextInputFormatter> inputFormatters;
  final Widget? trailingWidget;
  final int? maxLength;
  final bool obscureText;
  final FocusNode? focusNode;

  /// Called when Enter is pressed in the field.
  final VoidCallback? onSubmitted;

  final TextEditingController textEditingController = TextEditingController();

  final border = OutlineInputBorder(
    borderSide: BorderSide.none,
  );

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        String finalHintText = hintText;

        if (isEnabled && isRequired && finalHintText.isEmpty) {
          finalHintText = 'input required';
        }

        return Padding(
          padding: const EdgeInsets.all(4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4),
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
                            fontWeight: FontWeight.w500,
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
                hasError:
                    isEnabled && hasError && rxString.value.trim().isEmpty,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        focusNode: focusNode,
                        obscureText: obscureText,
                        maxLength: maxLength,
                        textAlignVertical: TextAlignVertical.center,
                        inputFormatters: inputFormatters,
                        style: TextStyle(
                          color: VardhmanColors.darkGrey,
                          fontSize: 13,
                          fontWeight: isEnabled ? null : FontWeight.w500,
                        ),
                        minLines: minLines,
                        maxLines: minLines,
                        controller: TextEditingController.fromValue(
                          TextEditingValue(
                            text: rxString.value,
                            selection: TextSelection.collapsed(
                              offset: rxString.value.length,
                            ),
                          ),
                        ),
                        decoration: InputDecoration(
                          counter: const SizedBox(),
                          hintText: finalHintText,
                          hintStyle: TextStyle(
                            color: VardhmanColors.darkGrey,
                            fontSize: 13,
                          ),
                          contentPadding: EdgeInsets.only(left: 8),
                          border: border,
                          enabledBorder: border,
                          focusedBorder: border,
                        ),
                        onChanged: (value) => rxString.value = value,
                        onSubmitted:
                            onSubmitted == null ? null : (_) => onSubmitted!(),
                        // Keep the cursor here after Enter (Flutter's default
                        // drops it), e.g. to retype a wrong OTP.
                        onEditingComplete: onSubmitted == null ? null : () {},
                        enabled: isEnabled,
                      ),
                    ),
                    if (isEnabled && rxString.value.isNotEmpty)
                      SecondaryButton(
                        wait: false,
                        iconData: Icons.clear,
                        text: '',
                        onPressed: () async {
                          rxString.value = '';
                        },
                      ),
                    if (trailingWidget != null) trailingWidget!,
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
