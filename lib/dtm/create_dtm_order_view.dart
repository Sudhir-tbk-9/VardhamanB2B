import 'package:data_table_2/data_table_2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:vardhman_b2b/orders/direct_delivery_tc.dart';
import 'package:vardhman_b2b/common/clear_drafts.dart';
import 'package:vardhman_b2b/common/header_view.dart';
import 'package:vardhman_b2b/common/new_order_date_field.dart';
import 'package:vardhman_b2b/common/order_detail_cell.dart';
import 'package:vardhman_b2b/common/order_detail_column_label.dart';
import 'package:vardhman_b2b/common/primary_button.dart';
import 'package:vardhman_b2b/common/secondary_button.dart';
import 'package:vardhman_b2b/common/ship_to_selector.dart';
import 'package:vardhman_b2b/common/catalog_search_field.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/dtm/dtm_entry_controller.dart';
import 'package:vardhman_b2b/common/new_order_text_field.dart';
import 'package:vardhman_b2b/common/direct_delivery_tc_box.dart';
import 'package:vardhman_b2b/common/form_section.dart';
import 'package:vardhman_b2b/common/order_form_title.dart';
import 'package:vardhman_b2b/orders/order_review_controller.dart';
import 'package:vardhman_b2b/common/adaptive_row.dart';
import 'package:vardhman_b2b/common/table_header.dart';
import 'package:vardhman_b2b/common/light_sources.dart';

class CreateDtmOrderView extends StatelessWidget {
  const CreateDtmOrderView({super.key});

  @override
  Widget build(BuildContext context) {
    final dtmEntryController = Get.find<DtmEntryController>();

    final OrderReviewController orderReviewController =
        Get.find<OrderReviewController>();

    return Column(
      children: <Widget>[
        HeaderView(
          elevation: 4,
          // Slim: leaves the form room to fit without scrolling.
          dense: true,
          leading: SecondaryButton(
            wait: false,
            iconData: Icons.arrow_back_ios_new,
            text: 'Back',
            onPressed: () async {
              Get.back();
            },
          ),
          title: OrderFormTitle(
            icon: Icons.design_services_outlined,
            title: 'New DTM Order',
          ),
          trailing: DefaultTextStyle(
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
            child: Obx(
              () => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Only once the draft has lines: deletes this draft
                  // order's lines and clears the form; the screen stays.
                  if (dtmEntryController.rxDtmOrderLines.isNotEmpty) ...[
                    ClearDraftsButton(
                      text: 'Clear Draft',
                      orderType: 'DT',
                      orderNumber: dtmEntryController.orderNumber,
                      confirmTitle: 'Clear this draft?',
                      confirmMessage: 'This draft order and its '
                          '${dtmEntryController.rxDtmOrderLines.length} line(s) will be '
                          'deleted.',
                      // The modal stays open: its lines are gone (the draft is
                      // deleted) and the form is cleared, as with Clear Inputs.
                      onCleared: () {
                        dtmEntryController.clearAllInputs();

                        dtmEntryController.rxSelectedDtmOrderLines.clear();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  PrimaryButton(
                    text: 'Submit Order',
                    onPressed: dtmEntryController.rxDtmOrderLines.isEmpty
                        ? null
                        : dtmEntryController.submitOrder,
                  ),
                ],
              ),
            ),
          ),
        ),
        const ShipToBar(),
        // The form takes the height it needs, so it does not scroll; the
        // lines table below gets the rest. Only a window too short for the
        // form and a few lines makes it scroll.
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: formMaxHeight(context),
          ),
          child: SingleChildScrollView(
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: LayoutBuilder(
                // Obx: the form is built here, outside the screen's Obx, so
                // fields enabled by other fields (Shade after Article, UOM
                // after Shade) would otherwise never update.
                builder: (context, constraints) => Obx(() {
                  final actions = FormActionsBar(
                    child: AdaptiveRow(
                      narrowLayout: NarrowLayout.wrap,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Spacer(),
                        RichText(
                          text: TextSpan(
                            text: '*',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            children: [
                              TextSpan(
                                text: ' required field',
                                style: TextStyle(
                                  color: VardhmanColors.darkGrey,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            ],
                          ),
                        ),
                        Spacer(),
                        SecondaryButton(
                          wait: false,
                          text: 'Clear Inputs',
                          onPressed: !dtmEntryController.canClearInputs
                              ? null
                              : () async {
                                  dtmEntryController.clearAllInputs();

                                  dtmEntryController.rxSelectedDtmOrderLines
                                      .clear();
                                },
                        ),
                        Spacer(),
                        PrimaryButton(
                          text: 'Add Line',
                          onPressed: dtmEntryController
                                  .rxSelectedDtmOrderLines.isNotEmpty
                              ? null
                              : () async {
                                  dtmEntryController.addDtmOrderLine();
                                },
                        ),
                        Spacer(),
                        PrimaryButton(
                          text: 'Update',
                          onPressed: dtmEntryController
                                      .rxSelectedDtmOrderLines.length ==
                                  1
                              ? () async {
                                  dtmEntryController.updateDtmOrderLine();
                                }
                              : null,
                        ),
                        Spacer(),
                        PrimaryButton(
                          text: 'Delete',
                          onPressed:
                              dtmEntryController.rxSelectedDtmOrderLines.isEmpty
                                  ? null
                                  : () async {
                                      dtmEntryController.deleteSelectedLines();
                                    },
                        ),
                        Spacer(),
                      ],
                    ),
                  );

                  return AdaptiveRow(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Spacer(),
                      Expanded(
                        flex: 4,
                        child: FormSection(
                          title: 'Order & Buyer',
                          icon: Icons.assignment_outlined,
                          child: Column(
                            children: <Widget>[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: NewOrderTextField(
                                      inputFormatters: [capitalFormatter],
                                      labelText: 'PO Number',
                                      isRequired: true,
                                      hasError:
                                          dtmEntryController.poNumberHasError,
                                      rxString: dtmEntryController.rxPoNumber,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 4,
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: NewOrderTextField(
                                      isEnabled: false,
                                      labelText: 'Upload PO Document',
                                      rxString: dtmEntryController.rxPoFileName,
                                      hintText: 'no file chosen',
                                      trailingWidget: dtmEntryController
                                              .rxPoFileName.isEmpty
                                          ? SecondaryButton(
                                              wait: false,
                                              text: 'Choose File',
                                              onPressed: () async {
                                                final FilePickerResult?
                                                    filePickerResult =
                                                    await FilePicker.platform
                                                        .pickFiles(
                                                  type: FileType.custom,
                                                  allowedExtensions: [
                                                    'pdf',
                                                    'xlsx'
                                                  ],
                                                  withData: true,
                                                  readSequential: true,
                                                );

                                                if (filePickerResult != null) {
                                                  final file = filePickerResult
                                                      .files.single;

                                                  dtmEntryController
                                                      .rxPoFileName
                                                      .value = file.name;

                                                  dtmEntryController
                                                      .rxPoFileBytes
                                                      .value = file.bytes;
                                                }
                                              },
                                            )
                                          : SecondaryButton(
                                              wait: false,
                                              iconData: Icons.clear,
                                              text: '',
                                              onPressed: () async {
                                                dtmEntryController
                                                    .rxPoFileName.value = '';

                                                dtmEntryController
                                                    .rxPoFileBytes.value = null;
                                              },
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                              CatalogSearchField(
                                isRequired: true,
                                labelText: 'Merchandiser',
                                rxString: dtmEntryController.rxMerchandiser,
                                searchList: dtmEntryController.rxMerchandisers,
                                shouldEnforceList: false,
                                hasError:
                                    dtmEntryController.merchandiserHasError,
                                inputFormatters: [capitalFormatter],
                              ),
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: CatalogSearchField(
                                      hasError:
                                          dtmEntryController.buyerNameHasError,
                                      labelText: 'Buyer',
                                      isRequired: true,
                                      rxString: dtmEntryController.rxBuyerName,
                                      searchList: dtmEntryController.buyerNames,
                                      inputFormatters: [capitalFormatter],
                                    ),
                                  ),
                                  if (dtmEntryController.isOtherBuyer) ...[
                                    SizedBox(
                                      width: 4,
                                    ),
                                    Expanded(
                                      child: NewOrderTextField(
                                        inputFormatters: [capitalFormatter],
                                        hasError: dtmEntryController
                                            .otherBuyerNameHasError,
                                        labelText: 'Name',
                                        isRequired: true,
                                        rxString:
                                            dtmEntryController.rxOtherBuyerName,
                                      ),
                                    ),
                                  ]
                                ],
                              ),
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: CatalogSearchField(
                                      isSearchboxEnabled: false,
                                      hasError: dtmEntryController
                                          .firstLightSourceHasError,
                                      isRequired: true,
                                      isEnabled: dtmEntryController
                                          .isLightSource1Enabled,
                                      labelText: 'Light Source 1',
                                      rxString:
                                          dtmEntryController.rxFirstLightSource,
                                      searchList:
                                          dtmEntryController.firstLightSources,
                                      inputFormatters: [capitalFormatter],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 4,
                                  ),
                                  Expanded(
                                    child: CatalogSearchField(
                                      isSearchboxEnabled: false,
                                      isEnabled: dtmEntryController
                                          .isLightSource2Enabled,
                                      labelText: 'Light Source 2',
                                      rxString: dtmEntryController
                                          .rxSecondLightSource,
                                      searchList:
                                          dtmEntryController.secondLightSources,
                                      inputFormatters: [capitalFormatter],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 10,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            AdaptiveRow(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Spacer(),
                                Expanded(
                                  flex: 4,
                                  child: FormSection(
                                    title: 'Article & Shade',
                                    icon: Icons.category_outlined,
                                    child: Column(
                                      children: <Widget>[
                                        Row(
                                          children: <Widget>[
                                            Expanded(
                                              flex: 2,
                                              child: CatalogSearchField(
                                                hasError: dtmEntryController
                                                    .articleHasError,
                                                labelText: 'Article',
                                                onChanged: dtmEntryController
                                                    .onArticlePicked,
                                                isRequired: true,
                                                rxString: dtmEntryController
                                                    .rxArticle,
                                                searchList: dtmEntryController
                                                    .uniqueFilteredArticles,
                                                inputFormatters: [
                                                  capitalFormatter
                                                ],
                                              ),
                                            ),
                                            SizedBox(
                                              width: 4,
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: CatalogSearchField(
                                                inputFormatters: [
                                                  capitalFormatter
                                                ],
                                                hasError: dtmEntryController
                                                    .shadeHasError,
                                                labelText: 'Shade',
                                                onChanged: dtmEntryController
                                                    .onShadePicked,
                                                isRequired: true,
                                                isEnabled: dtmEntryController
                                                    .rxArticle.isNotEmpty,
                                                rxString:
                                                    dtmEntryController.rxShade,
                                                dropdownKey: dtmEntryController
                                                    .shadeDropdownKey,
                                                searchList:
                                                    dtmEntryController.rxShades,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: <Widget>[
                                            Expanded(
                                              flex: 2,
                                              child: CatalogSearchField(
                                                inputFormatters: [
                                                  capitalFormatter
                                                ],
                                                isEnabled: false,
                                                labelText: 'Ticket',
                                                rxString:
                                                    dtmEntryController.rxTicket,
                                                searchList: [],
                                              ),
                                            ),
                                            SizedBox(
                                              width: 4,
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: CatalogSearchField(
                                                inputFormatters: [
                                                  capitalFormatter
                                                ],
                                                labelText: 'Brand',
                                                rxString:
                                                    dtmEntryController.rxBrand,
                                                searchList: [],
                                                isEnabled: false,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: <Widget>[
                                            Expanded(
                                              flex: 2,
                                              child: CatalogSearchField(
                                                inputFormatters: [
                                                  capitalFormatter
                                                ],
                                                labelText: 'Tex',
                                                isEnabled: false,
                                                rxString:
                                                    dtmEntryController.rxTex,
                                                searchList: [],
                                              ),
                                            ),
                                            SizedBox(
                                              width: 4,
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: CatalogSearchField(
                                                inputFormatters: [
                                                  capitalFormatter
                                                ],
                                                isEnabled: false,
                                                labelText: 'Substrate',
                                                rxString: dtmEntryController
                                                    .rxSubstrate,
                                                searchList: [],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Spacer(),
                                Expanded(
                                  flex: 4,
                                  child: FormSection(
                                    title: 'Line Details',
                                    icon: Icons.tune,
                                    child: Column(
                                      children: <Widget>[
                                        Row(
                                          children: <Widget>[
                                            Expanded(
                                              child: CatalogSearchField(
                                                inputFormatters: [
                                                  capitalFormatter
                                                ],
                                                isRequired: true,
                                                hasError: dtmEntryController
                                                    .uomHasError,
                                                // Article -> Shade -> UOM: UOM follows
                                                // from the shade (Sno 14).
                                                isEnabled: !dtmEntryController
                                                        .rxUomLocked.value &&
                                                    (dtmEntryController.rxShade
                                                            .isNotEmpty ||
                                                        dtmEntryController
                                                            .rxUom.isNotEmpty),
                                                dropdownKey: dtmEntryController
                                                    .uomDropdownKey,
                                                labelText: 'UOM',
                                                rxString: dtmEntryController
                                                    .rxUomWithDesc,
                                                searchList: dtmEntryController
                                                    .uomChoices
                                                    .map(
                                                  (uom) {
                                                    return '$uom - ${orderReviewController.getUomDescription(uom)}';
                                                  },
                                                ).toList(),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 4,
                                            ),
                                            Expanded(
                                              child: NewOrderTextField(
                                                inputFormatters: [
                                                  capitalFormatter
                                                ],
                                                hasError: dtmEntryController
                                                    .colorHasError,
                                                labelText: 'Color Name',
                                                rxString:
                                                    dtmEntryController.rxColor,
                                                isRequired: true,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: NewOrderTextField(
                                                labelText: 'Quantity',
                                                isRequired: true,
                                                maxLength: 10,
                                                rxString: dtmEntryController
                                                    .rxQuantity,
                                                hasError: dtmEntryController
                                                    .quantityHasError,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter
                                                      .allow(
                                                    RegExp(r'^[1-9]\d*'),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(
                                              width: 4,
                                            ),
                                            Expanded(
                                              child: NewOrderDateField(
                                                labelText:
                                                    'Expected Delivery Date',
                                                rxDate: dtmEntryController
                                                    .rxRequestedDate,
                                                hintText: 'select',
                                                firstDate: earliestEdd,
                                              ),
                                            ),
                                          ],
                                        ),
                                        // Remark full width; the TC box
                                        // (only for an article with an "R")
                                        // below it, not beside it.
                                        NewOrderTextField(
                                          inputFormatters: [capitalFormatter],
                                          labelText: 'Remark',
                                          rxString: dtmEntryController.rxRemark,
                                          maxLength: remarkMaxLength,
                                          showLength: true,
                                          hintText: 'Enter Remark',
                                          // A text area: long remarks wrap
                                          // over 2 lines (low, so the lines
                                          // table below keeps its room).
                                          minLines: 2,
                                          // After a system "TC Required": the
                                          // user can add a remark of their own.
                                          inlineHint:
                                              DirectDeliveryTc.tcRemarkHint,
                                        ),
                                        if (dtmEntryController.offersTc) ...[
                                          SizedBox(height: 2),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: DirectDeliveryTcBox(
                                              controller: dtmEntryController,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                Spacer(),
                              ],
                            ),
                            SizedBox(
                              height: 24,
                            ),
                            actions,
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
        Expanded(
          // Its own Obx: adding or selecting a line rebuilds the table
          // only, not the form above it.
          child: Obx(
            () => DataTable2(
              isHorizontalScrollBarVisible: true,
              isVerticalScrollBarVisible: true,
              minWidth: 1720,
              columnSpacing: 0,
              showBottomBorder: true,
              border: TableBorder.symmetric(
                inside: BorderSide(color: VardhmanColors.darkGrey, width: 0.2),
                outside: BorderSide(color: VardhmanColors.darkGrey, width: 0.2),
              ),
              headingCheckboxTheme: CheckboxThemeData(
                fillColor: WidgetStatePropertyAll(Colors.white),
                checkColor: WidgetStatePropertyAll(VardhmanColors.red),
              ),
              datarowCheckboxTheme: CheckboxThemeData(
                fillColor: WidgetStatePropertyAll(Colors.white),
                checkColor: WidgetStatePropertyAll(VardhmanColors.red),
              ),
              dataTextStyle: TextStyle(
                color: VardhmanColors.darkGrey,
                fontSize: 13,
              ),
              checkboxHorizontalMargin: 0,
              horizontalMargin: 16,
              headingRowHeight: 60,
              dataRowHeight: 60,
              headingRowDecoration: TableHeader.decoration,
              headingTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              columns: const [
                DataColumn2(
                  label: OrderDetailColumnLabel(labelText: '#'),
                  fixedWidth: 50,
                  headingRowAlignment: MainAxisAlignment.end,
                ),
                DataColumn2(
                  label: OrderDetailColumnLabel(labelText: 'Merchandiser'),
                  size: ColumnSize.S,
                  headingRowAlignment: MainAxisAlignment.end,
                ),
                DataColumn2(
                  label: OrderDetailColumnLabel(labelText: 'Buyer'),
                  size: ColumnSize.M,
                  headingRowAlignment: MainAxisAlignment.end,
                ),
                DataColumn2(
                  label: OrderDetailColumnLabel(labelText: 'Light Source'),
                  size: ColumnSize.M,
                  headingRowAlignment: MainAxisAlignment.end,
                ),
                DataColumn2(
                  label: OrderDetailColumnLabel(labelText: 'Article'),
                  size: ColumnSize.S,
                  headingRowAlignment: MainAxisAlignment.end,
                ),
                DataColumn2(
                  label: OrderDetailColumnLabel(labelText: 'UOM'),
                  size: ColumnSize.M,
                  headingRowAlignment: MainAxisAlignment.end,
                ),
                DataColumn2(
                  label: OrderDetailColumnLabel(labelText: 'Ticket'),
                  size: ColumnSize.S,
                  headingRowAlignment: MainAxisAlignment.end,
                ),
                DataColumn2(
                  label: OrderDetailColumnLabel(labelText: 'Brand'),
                  size: ColumnSize.S,
                  headingRowAlignment: MainAxisAlignment.end,
                ),
                DataColumn2(
                  label: OrderDetailColumnLabel(labelText: 'Tex'),
                  size: ColumnSize.S,
                  headingRowAlignment: MainAxisAlignment.end,
                ),
                DataColumn2(
                  label: OrderDetailColumnLabel(labelText: 'Substrate'),
                  size: ColumnSize.S,
                  headingRowAlignment: MainAxisAlignment.end,
                ),
                DataColumn2(
                  label: OrderDetailColumnLabel(labelText: 'Shade'),
                  size: ColumnSize.S,
                  headingRowAlignment: MainAxisAlignment.end,
                ),
                DataColumn2(
                  label: OrderDetailColumnLabel(labelText: 'Style/Part No.'),
                  size: ColumnSize.S,
                  headingRowAlignment: MainAxisAlignment.end,
                ),
                DataColumn2(
                  label: OrderDetailColumnLabel(labelText: 'Quantity'),
                  size: ColumnSize.S,
                  headingRowAlignment: MainAxisAlignment.end,
                ),
                DataColumn2(
                  label: OrderDetailColumnLabel(
                      labelText: 'Expected Delivery Date'),
                  size: ColumnSize.S,
                  headingRowAlignment: MainAxisAlignment.end,
                ),
                DataColumn2(
                  label: OrderDetailColumnLabel(labelText: 'Remark'),
                  size: ColumnSize.M,
                  headingRowAlignment: MainAxisAlignment.end,
                ),
              ],
              empty: Center(child: const Text('No Order Lines')),
              rows: dtmEntryController.dtmOrderLinesDescending.map(
                (dtmOrderLine) {
                  final index =
                      dtmEntryController.rxDtmOrderLines.indexOf(dtmOrderLine);

                  final uomDesc =
                      orderReviewController.getUomDescription(dtmOrderLine.uom);

                  return DataRow(
                    color: index.isEven
                        ? WidgetStatePropertyAll(Colors.white)
                        : WidgetStatePropertyAll(
                            VardhmanColors.dividerGrey.withAlpha(128)),
                    selected: dtmEntryController.rxSelectedDtmOrderLines
                        .contains(dtmOrderLine),
                    onSelectChanged: (_) {
                      dtmEntryController.selectDtmOrderLine(dtmOrderLine);
                    },
                    cells: [
                      DataCell(
                        OrderDetailCell(
                          cellText: (index + 1).toString(),
                        ),
                      ),
                      DataCell(
                        OrderDetailCell(
                          cellText: dtmOrderLine.merchandiser,
                        ),
                      ),
                      DataCell(
                        OrderDetailCell(
                          cellText: dtmOrderLine.buyer,
                        ),
                      ),
                      DataCell(
                        OrderDetailCell(
                          cellText: dtmOrderLine.lightSourcesText,
                        ),
                      ),
                      DataCell(
                        OrderDetailCell(
                          cellText: dtmOrderLine.article,
                        ),
                      ),
                      DataCell(
                        OrderDetailCell(
                          cellText: "${dtmOrderLine.uom} - $uomDesc",
                        ),
                      ),
                      DataCell(
                        OrderDetailCell(
                          cellText: dtmOrderLine.ticket,
                        ),
                      ),
                      DataCell(
                        OrderDetailCell(
                          cellText: dtmOrderLine.brand,
                        ),
                      ),
                      DataCell(
                        OrderDetailCell(
                          cellText: dtmOrderLine.tex,
                        ),
                      ),
                      DataCell(
                        OrderDetailCell(
                          cellText: dtmOrderLine.substrate,
                        ),
                      ),
                      DataCell(
                        OrderDetailCell(
                          cellText: dtmOrderLine.shade,
                        ),
                      ),
                      DataCell(
                        OrderDetailCell(
                          cellText: dtmOrderLine.colorName,
                        ),
                      ),
                      DataCell(
                        OrderDetailCell(
                          cellText: dtmOrderLine.quantity.toString(),
                        ),
                      ),
                      DataCell(
                        OrderDetailCell(
                          cellText: dtmOrderLine.requestedDate == null
                              ? ''
                              : DateFormat('d MMM yyyy')
                                  .format(dtmOrderLine.requestedDate!),
                        ),
                      ),
                      DataCell(
                        OrderDetailCell(
                          cellText: dtmOrderLine.remark,
                        ),
                      ),
                    ],
                  );
                },
              ).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
