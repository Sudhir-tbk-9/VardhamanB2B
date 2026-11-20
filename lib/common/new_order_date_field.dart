import 'package:date_field/date_field.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:vardhman_b2b/app/theme_variants.dart';
import 'package:vardhman_b2b/common/secondary_button.dart';
import 'package:vardhman_b2b/constants.dart';

/// Days from today, today included, that cannot be picked as the Expected
/// Delivery Date (EDD): today and the next 10 days.
const blockedEddDays = 11;

/// Earliest Expected Delivery Date (EDD) on the Bulk and DTM forms: today
/// and the next 10 days cannot be picked.
DateTime get earliestEdd => DateUtils.dateOnly(DateTime.now())
    .add(const Duration(days: blockedEddDays));

class NewOrderDateField extends StatelessWidget {
  NewOrderDateField({
    super.key,
    required this.labelText,
    this.hintText = '',
    required this.rxDate,
    this.isEnabled = true,
    this.minLines,
    this.isRequired = false,
    this.hasError = false,
    this.firstDate,
    this.pickerNote,
  });

  /// Shown in a card under the calendar, if given. The EDD calendar shows
  /// none: the days before [firstDate] are only greyed out.
  final String? pickerNote;

  final String labelText;
  final String hintText;
  final Rxn<DateTime> rxDate;
  final bool isEnabled;
  final int? minLines;
  final bool isRequired;
  final bool hasError;
  final DateTime? firstDate;

  final noneBorder = OutlineInputBorder(
    borderSide: BorderSide.none,
  );

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
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
                      fontWeight: FontWeight.bold,
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
              Container(
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isEnabled && hasError && rxDate.value == null
                        ? VardhmanColors.red
                        : VardhmanColors.darkGrey,
                    width: 1.5,
                  ),
                  color: isEnabled ? Colors.white : VardhmanColors.dividerGrey,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: DateTimeField(
                        padding: EdgeInsets.only(top: 4),
                        mode: DateTimeFieldPickerMode.date,
                        decoration: InputDecoration(
                          errorBorder: noneBorder,
                          focusedBorder: noneBorder,
                          enabledBorder: noneBorder,
                          focusedErrorBorder: noneBorder,
                          border: OutlineInputBorder(),
                          suffixIcon: Container(),
                          hintText: isEnabled ? 'select' : null,
                          hintStyle: TextStyle(
                            color: VardhmanColors.darkGrey,
                            fontSize: 13,
                          ),
                          prefixText: rxDate.value != null
                              ? DateFormat('d MMM yyyy').format(rxDate.value!)
                              : null,
                          prefixStyle: TextStyle(
                            color: VardhmanColors.darkGrey,
                            fontSize: 13,
                          ),
                          contentPadding: EdgeInsets.only(
                            left: 8,
                            top: 0,
                          ),
                        ),
                        firstDate: firstDate,
                        // A date before firstDate (e.g. a draft saved days
                        // ago) would make the picker fail: it opens on
                        // firstDate instead. The field still shows the date.
                        value: firstDate != null &&
                                rxDate.value != null &&
                                rxDate.value!.isBefore(firstDate!)
                            ? null
                            : rxDate.value,
                        initialPickerDateTime: firstDate,
                        // Calendar only: typing a date would resize the
                        // dialog away from the note under it.
                        materialDatePickerOptions: MaterialDatePickerOptions(
                          initialEntryMode: pickerNote == null
                              ? DatePickerEntryMode.calendar
                              : DatePickerEntryMode.calendarOnly,
                          builder: _buildPicker,
                        ),
                        onChanged: (DateTime? date) {
                          if (date != null) {
                            rxDate.value = date;
                          }
                        },
                      ),
                    ),
                    if (isEnabled && rxDate.value != null)
                      SecondaryButton(
                        wait: false,
                        iconData: Icons.clear,
                        text: '',
                        onPressed: () async {
                          rxDate.value = null;
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The calendar: dates before [firstDate] greyed out (grey circle, grey
  /// number), and [pickerNote] in a card right under the dialog.
  Widget _buildPicker(BuildContext context, Widget? child) {
    final theme = Theme.of(context);

    final disabledForeground = VardhmanColors.darkGrey.withAlpha(100);

    final disabledBackground = VardhmanColors.dividerGrey.withAlpha(170);

    final today = DateUtils.dateOnly(DateTime.now());

    final isTodayBlocked = firstDate != null && firstDate!.isAfter(today);

    Color? whenDisabled(Set<WidgetState> states, Color color) =>
        states.contains(WidgetState.disabled) ? color : null;

    final picker = Theme(
      data: theme.copyWith(
        datePickerTheme: theme.datePickerTheme.copyWith(
          dayForegroundColor: WidgetStateProperty.resolveWith(
            (states) => whenDisabled(states, disabledForeground),
          ),
          dayBackgroundColor: WidgetStateProperty.resolveWith(
            (states) => whenDisabled(states, disabledBackground),
          ),
          todayForegroundColor: WidgetStateProperty.resolveWith(
            (states) => whenDisabled(states, disabledForeground),
          ),
          todayBackgroundColor: WidgetStateProperty.resolveWith(
            (states) => whenDisabled(states, disabledBackground),
          ),
          // Today is not highlighted when it cannot be picked.
          todayBorder:
              isTodayBlocked ? BorderSide(color: disabledForeground) : null,
        ),
      ),
      child: child!,
    );

    final note = pickerNote;

    if (note == null) {
      return picker;
    }

    // The dialog is centred and sized as DatePickerDialog sizes it
    // (calendar only), so the note goes right under it.
    final orientation = MediaQuery.orientationOf(context);

    final dialogSize = orientation == Orientation.landscape
        ? const Size(496, 346)
        : theme.useMaterial3
            ? const Size(360, 568)
            : const Size(330, 518);

    final textScale =
        MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 3).scale(14) /
            14;

    final variant = ThemeVariants.current;

    return LayoutBuilder(
      builder: (context, constraints) {
        final dialogHeight = dialogSize.height * textScale;

        return Stack(
          children: [
            Positioned.fill(child: picker),
            Positioned(
              top: constraints.maxHeight / 2 + dialogHeight / 2 + 8,
              left: 0,
              right: 0,
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: dialogSize.width * textScale,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                        variant.warning.withAlpha(36),
                        Colors.white,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: variant.warning.withAlpha(120)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: variant.warning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            note,
                            style: TextStyle(
                              color: VardhmanColors.darkGrey,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
