import 'package:data_table_2/data_table_2.dart';
import 'package:vardhman_b2b/common/date_range_chips.dart';
import 'package:vardhman_b2b/common/paged_orders_table.dart';
import 'package:date_field/date_field.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:toastification/toastification.dart';
import 'package:vardhman_b2b/api/api.dart';
import 'package:vardhman_b2b/common/header_view.dart';
import 'package:vardhman_b2b/common/primary_button.dart';
import 'package:vardhman_b2b/common/secondary_button.dart';
import 'package:vardhman_b2b/common/vardhman_loader.dart';
import 'package:vardhman_b2b/api/order_header_line.dart';
import 'package:vardhman_b2b/drift/database.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/dtm/create_dtm_order_view.dart';
import 'package:vardhman_b2b/dtm/dtm_controller.dart';
import 'package:vardhman_b2b/dtm/dtm_entry_controller.dart';
import 'package:vardhman_b2b/common/adaptive_dialog.dart';

class DtmOrdersView extends StatelessWidget {
  const DtmOrdersView({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final DtmController dtmController = Get.find<DtmController>();

    return Obx(
      () {
        // Kept up to date by the controller as orders and filters change.
        final filteredOrders = dtmController.filteredDtmOrders;

        return Column(
        children: [
          HeaderView(
            leading: SecondaryButton(
              iconData: Icons.refresh,
              text: '',
              onPressed: dtmController.refreshOrders,
            ),
            title: Text(
              'DTM Orders',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: VardhmanColors.darkGrey,
              ),
            ),
            trailing: PrimaryButton(
              text: 'New Order',
              onPressed: () async {
                final newOrderNumber = await Api.fetchDraftOrderNumber();

                if (newOrderNumber != null) {
                  if (Get.isRegistered<DtmEntryController>()) {
                    Get.delete<DtmEntryController>();
                  }

                  Get.put(
                    DtmEntryController(
                      orderNumber: newOrderNumber,
                    ),
                  );

                  Get.dialog(
                    const AdaptiveDialog(
                      clipBehavior: Clip.hardEdge,
                      child: CreateDtmOrderView(),
                    ),
                  );
                } else {
                  toastification.show(
                    autoCloseDuration: Duration(seconds: 3),
                    primaryColor: VardhmanColors.red,
                    title: Text('Failed to fetch new order number!'),
                  );
                }
              },
            ),
          ),
          Expanded(
            child: LoadingOverlay(
              isLoading: dtmController.ordersController.isLoading,
              child: filteredOrders.isEmpty &&
                      dtmController.rxDraftOrders.isEmpty
                  ? const Center(
                      child: Text('No DTM Orders'),
                    )
                  : Container(
                      padding: const EdgeInsets.all(0),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                      ),
                      child: PagedOrdersTable(
                        minWidth: 600,
                        columns: const [
                          DataColumn2(
                            label: Text('Order No.'),
                            headingRowAlignment: MainAxisAlignment.start,
                            size: ColumnSize.L,
                          ),
                          DataColumn2(
                            label: Text('Date'),
                            size: ColumnSize.S,
                            headingRowAlignment: MainAxisAlignment.center,
                          ),
                          DataColumn2(
                            label: Text('PO Number'),
                            size: ColumnSize.S,
                            headingRowAlignment: MainAxisAlignment.center,
                          ),
                          DataColumn2(
                            label: Text('Merchandiser'),
                            size: ColumnSize.M,
                            headingRowAlignment: MainAxisAlignment.center,
                          ),
                        ],
                        rowCount: () =>
                            dtmController.rxDraftOrders.length +
                            filteredOrders.length,
                        // Called only for the rows of the page on screen.
                        rowBuilder: (int rowIndex) {
                          DataRow draftRow((int, DraftTableData) entry) {
                            final (index, draftTableData) = entry;

                            return DataRow(
                              color: WidgetStatePropertyAll(
                                index.isEven
                                    ? Colors.white
                                    : VardhmanColors.dividerGrey
                                        .withAlpha(128),
                              ),
                              onSelectChanged: (value) {
                                if (Get.isRegistered<DtmEntryController>()) {
                                  Get.delete<DtmEntryController>();
                                }

                                Get.put(
                                  DtmEntryController(
                                    orderNumber: draftTableData.orderNumber,
                                  ),
                                );

                                Get.dialog(
                                  const AdaptiveDialog(
                                    clipBehavior: Clip.hardEdge,
                                    child: CreateDtmOrderView(),
                                  ),
                                );
                              },
                              cells: [
                                DataCell(
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: <Widget>[
                                        Text(
                                          'Draft',
                                          textAlign: TextAlign.end,
                                        ),
                                        SizedBox(
                                          width: 16,
                                        ),
                                        Text(
                                          draftTableData.orderNumber
                                              .toString(),
                                          textAlign: TextAlign.end,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Align(
                                    alignment: Alignment.center,
                                    child: Text(
                                      DateFormat('d MMM yy HH:mm').format(
                                        draftTableData.lastUpdated,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Align(
                                    alignment: Alignment.center,
                                    child: Text(
                                      draftTableData.poNumber,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Align(
                                    alignment: Alignment.center,
                                    child: Text(
                                      draftTableData.merchandiser,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }

                          DataRow orderRow((int, OrderHeaderLine) entry) {
                            final (filteredIndex, orderHeaderLine) = entry;

                            final index =
                                filteredIndex + dtmController.rxDraftOrders.length;

                            final isSelected = dtmController
                                    .rxSelectedOrderHeaderLine.value ==
                                orderHeaderLine;

                            final textStyle = TextStyle(
                              fontSize: 13,
                              color: isSelected
                                  ? Colors.white
                                  : VardhmanColors.darkGrey,
                            );

                            return DataRow(
                              color: WidgetStatePropertyAll(
                                isSelected
                                    ? VardhmanColors.red
                                    : index.isEven
                                        ? Colors.white
                                        : VardhmanColors.dividerGrey
                                            .withAlpha(128),
                              ),
                              selected: orderHeaderLine ==
                                  dtmController
                                      .rxSelectedOrderHeaderLine.value,
                              onSelectChanged: (value) {
                                if (value == true &&
                                    dtmController.rxSelectedOrderHeaderLine
                                            .value !=
                                        orderHeaderLine) {
                                  dtmController.selectOrder(orderHeaderLine);
                                }
                              },
                              cells: [
                                DataCell(
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: DefaultTextStyle(
                                      style: textStyle,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: <Widget>[
                                          Text(
                                            orderHeaderLine.orderNumber
                                                .toString(),
                                            textAlign: TextAlign.end,
                                          ),
                                          if (orderHeaderLine.orderReference
                                              .trim()
                                              .isNotEmpty) ...[
                                            SizedBox(
                                              width: 16,
                                            ),
                                            Text(
                                              orderHeaderLine.orderReference,
                                              textAlign: TextAlign.end,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Align(
                                    alignment: Alignment.center,
                                    child: Text(
                                      DateFormat('d MMM yy').format(
                                        orderHeaderLine.orderDate,
                                      ),
                                      style: textStyle,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Align(
                                    alignment: Alignment.center,
                                    child: Text(
                                      orderHeaderLine.poNumber,
                                      style: textStyle,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Align(
                                    alignment: Alignment.center,
                                    child: Text(
                                      orderHeaderLine.merchandiser,
                                      style: textStyle,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }

                          final draftCount = dtmController.rxDraftOrders.length;

                          return rowIndex < draftCount
                              ? draftRow((
                                  rowIndex,
                                  dtmController.rxDraftOrders[rowIndex],
                                ))
                              : orderRow((
                                  rowIndex - draftCount,
                                  filteredOrders[rowIndex - draftCount],
                                ));
                        },
                        refreshOn: [
                          dtmController.rxDraftOrders,
                          dtmController.rxFilteredOrders,
                          dtmController.rxSelectedOrderHeaderLine,
                        ],
                        firstPageOn: [dtmController.rxFilteredOrders],
                      ),
                    ),
            ),
          ),
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(top: 16, right: 8, left: 8, bottom: 8),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: DateRangeChips(filters: dtmController),
                ),
                SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Flexible(
                      child: TextField(
                        controller: TextEditingController.fromValue(
                          TextEditingValue(
                            text: dtmController.rxOrderNumberInput.value,
                            selection: TextSelection.collapsed(
                              offset:
                                  dtmController.rxOrderNumberInput.value.length,
                            ),
                          ),
                        ),
                        onChanged: (String orderNumber) {
                          dtmController.rxOrderNumberInput.value = orderNumber;
                        },
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          isDense: true,
                          label: Text('Order No.'),
                          labelStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: DateTimeField(
                        mode: DateTimeFieldPickerMode.date,
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: 'From Date',
                          border: OutlineInputBorder(),
                          suffixIcon: Container(),
                          prefixText: DateFormat('d MMM yy').format(
                            dtmController.rxOrderFromDate.value,
                          ),
                          prefixStyle: TextStyle(
                            color: dtmController.rxOrderFromDate.value
                                    .isAtSameMomentAs(oldestDateTime)
                                ? Colors.white
                                : VardhmanColors.darkGrey,
                            fontSize: 13,
                          ),
                        ),
                        firstDate: dtmController.rxEarliestOrderDate.value,
                        lastDate: dtmController.rxOrderToDate.value,
                        value: dtmController.rxOrderFromDate.value,
                        onChanged: (DateTime? date) {
                          if (date != null) {
                            dtmController.rxOrderFromDate.value = date;
                            dtmController.rxDateRange.value = null;
                          }
                        },
                      ),
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: DateTimeField(
                        mode: DateTimeFieldPickerMode.date,
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: 'To Date',
                          border: OutlineInputBorder(),
                          suffixIcon: Container(),
                          prefixText: DateFormat('d MMM yy').format(
                            dtmController.rxOrderToDate.value,
                          ),
                          prefixStyle: TextStyle(
                            color: VardhmanColors.darkGrey,
                            fontSize: 13,
                          ),
                        ),
                        firstDate: dtmController.rxOrderFromDate.value,
                        lastDate: DateTime.now(),
                        value: dtmController.rxOrderToDate.value,
                        onChanged: (DateTime? date) {
                          if (date != null) {
                            dtmController.rxOrderToDate.value = date;
                            dtmController.rxDateRange.value = null;
                          }
                        },
                      ),
                    ),
                    SizedBox(width: 8),
                    SecondaryButton(
                      wait: false,
                      iconData: FontAwesomeIcons.arrowRotateLeft.data,
                      text: '',
                      onPressed: dtmController.hasDefaultValues
                          ? null
                          : dtmController.setDefaultValues,
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Flexible(
                      child: TextField(
                        controller: TextEditingController.fromValue(
                          TextEditingValue(
                            text: dtmController.rxPoNumberInput.value,
                            selection: TextSelection.collapsed(
                              offset:
                                  dtmController.rxPoNumberInput.value.length,
                            ),
                          ),
                        ),
                        onChanged: (String poNumber) {
                          dtmController.rxPoNumberInput.value = poNumber;
                        },
                        keyboardType: TextInputType.number,
                        inputFormatters: [capitalFormatter],
                        decoration: InputDecoration(
                          isDense: true,
                          label: Text('PO Number'),
                          labelStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: TextField(
                        controller: TextEditingController.fromValue(
                          TextEditingValue(
                            text: dtmController.rxMerchandiserInput.value,
                            selection: TextSelection.collapsed(
                              offset: dtmController
                                  .rxMerchandiserInput.value.length,
                            ),
                          ),
                        ),
                        onChanged: (String merchandiser) {
                          dtmController.rxMerchandiserInput.value =
                              merchandiser;
                        },
                        keyboardType: TextInputType.number,
                        inputFormatters: [capitalFormatter],
                        decoration: InputDecoration(
                          isDense: true,
                          label: Text('Merchandiser'),
                          labelStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Flexible(
                      child: TextField(
                        controller: TextEditingController.fromValue(
                          TextEditingValue(
                            text: dtmController.rxShadeInput.value,
                            selection: TextSelection.collapsed(
                              offset: dtmController.rxShadeInput.value.length,
                            ),
                          ),
                        ),
                        onChanged: (String value) {
                          dtmController.rxShadeInput.value = value;
                        },
                        inputFormatters: [capitalFormatter],
                        decoration: InputDecoration(
                          isDense: true,
                          label: Text('Shade'),
                          labelStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: TextField(
                        controller: TextEditingController.fromValue(
                          TextEditingValue(
                            text: dtmController.rxBuyerInput.value,
                            selection: TextSelection.collapsed(
                              offset: dtmController.rxBuyerInput.value.length,
                            ),
                          ),
                        ),
                        onChanged: (String value) {
                          dtmController.rxBuyerInput.value = value;
                        },
                        inputFormatters: [capitalFormatter],
                        decoration: InputDecoration(
                          isDense: true,
                          label: Text('Buyer'),
                          labelStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                if (dtmController.rxLineSearchProgress.value != null) ...[
                  SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: dtmController.rxLineSearchProgress.value,
                  ),
                ],
              ],
            ),
          ),
        ],
        );
      },
    );
  }
}
