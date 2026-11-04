import 'package:data_table_2/data_table_2.dart';
import 'package:vardhman_b2b/common/adaptive_row.dart';
import 'package:vardhman_b2b/common/date_range_menu.dart';
import 'package:vardhman_b2b/common/order_filters_panel.dart';
import 'package:vardhman_b2b/common/order_pager.dart';
import 'package:vardhman_b2b/common/paged_orders_table.dart';
import 'package:date_field/date_field.dart';
import 'package:flutter/material.dart';
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
import 'package:vardhman_b2b/sampling/create_sampling_order_view.dart';
import 'package:vardhman_b2b/sampling/sampling_controller.dart';
import 'package:vardhman_b2b/sampling/sampling_entry_controller.dart';
import 'package:vardhman_b2b/common/adaptive_dialog.dart';

class SamplingOrdersView extends StatelessWidget {
  const SamplingOrdersView({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final SamplingController samplingController =
        Get.find<SamplingController>();

    return Obx(
      () {
        // Kept up to date by the controller as orders and filters change.
        final filteredOrders = samplingController.filteredSamplingOrders;

        final hasRows =
            filteredOrders.isNotEmpty || samplingController.rxDraftOrders.isNotEmpty;

        final feedbackOrderNumbers = samplingController.rxSamplingFeedbacks
            .map((feedback) => feedback.orderNumber)
            .toSet();

        return Column(
        children: [
          HeaderView(
            leading: SecondaryButton(
              iconData: Icons.refresh,
              text: '',
              onPressed: samplingController.refreshOrders,
            ),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sampling Orders',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: VardhmanColors.darkGrey,
                  ),
                ),
                if (hasRows)
                  OrderPager(controller: samplingController.paginatorController),
              ],
            ),
            trailing: PrimaryButton(
              text: 'New Order',
              onPressed: () async {
                final newOrderNumber = await Api.fetchDraftOrderNumber();

                if (newOrderNumber != null) {
                  if (Get.isRegistered<SamplingEntryController>()) {
                    Get.delete<SamplingEntryController>();
                  }

                  Get.put(
                    SamplingEntryController(
                      orderNumber: newOrderNumber,
                    ),
                  );

                  Get.dialog(
                    const AdaptiveDialog(
                      clipBehavior: Clip.hardEdge,
                      child: CreateSamplingOrderView(),
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
              isLoading: samplingController.ordersController.isLoading,
              child: filteredOrders.isEmpty &&
                      samplingController.rxDraftOrders.isEmpty
                  ? const Center(
                      child: Text('No Sampling Orders'),
                    )
                  : Container(
                      padding: const EdgeInsets.all(0),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                      ),
                      child: PagedOrdersTable(
                        minWidth: 450,
                        controller: samplingController.paginatorController,
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
                            label: Text('Merchandiser'),
                            size: ColumnSize.M,
                            headingRowAlignment: MainAxisAlignment.center,
                          ),
                        ],
                        rowCount: () =>
                            samplingController.rxDraftOrders.length +
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
                                if (Get.isRegistered<
                                    SamplingEntryController>()) {
                                  Get.delete<SamplingEntryController>();
                                }

                                Get.put(
                                  SamplingEntryController(
                                    orderNumber: draftTableData.orderNumber,
                                  ),
                                );

                                Get.dialog(
                                  const AdaptiveDialog(
                                    clipBehavior: Clip.hardEdge,
                                    child: CreateSamplingOrderView(),
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
                                filteredIndex + samplingController.rxDraftOrders.length;

                            final isSelected = samplingController
                                    .rxSelectedOrderHeaderLine.value ==
                                orderHeaderLine;

                            final hasFeedback = feedbackOrderNumbers
                                .contains(orderHeaderLine.orderNumber);

                            final textStyle = TextStyle(
                              fontSize: 13,
                              color: isSelected
                                  ? Colors.white
                                  : hasFeedback
                                      ? VardhmanColors.red
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
                                  samplingController
                                      .rxSelectedOrderHeaderLine.value,
                              onSelectChanged: (value) {
                                if (value == true &&
                                    samplingController
                                            .rxSelectedOrderHeaderLine
                                            .value !=
                                        orderHeaderLine) {
                                  samplingController
                                      .selectOrder(orderHeaderLine);
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
                                      orderHeaderLine.merchandiser,
                                      style: textStyle,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }

                          final draftCount = samplingController.rxDraftOrders.length;

                          return rowIndex < draftCount
                              ? draftRow((
                                  rowIndex,
                                  samplingController.rxDraftOrders[rowIndex],
                                ))
                              : orderRow((
                                  rowIndex - draftCount,
                                  filteredOrders[rowIndex - draftCount],
                                ));
                        },
                        refreshOn: [
                          samplingController.rxDraftOrders,
                          samplingController.rxFilteredOrders,
                          samplingController.rxSelectedOrderHeaderLine,
                        ],
                        firstPageOn: [samplingController.rxFilteredOrders],
                      ),
                    ),
            ),
          ),
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(8),
            child: OrderFiltersPanel(
              filters: samplingController,
              child: Column(
                children: [
                  AdaptiveRow(
                    breakpoint: 440,
                    narrowLayout: NarrowLayout.wrap,
                    minChildWidth: 140,
                    children: <Widget>[
                      Flexible(
                        child: TextField(
                          controller: TextEditingController.fromValue(
                            TextEditingValue(
                              text: samplingController.rxOrderNumberInput.value,
                              selection: TextSelection.collapsed(
                                offset: samplingController
                                    .rxOrderNumberInput.value.length,
                              ),
                            ),
                          ),
                          onChanged: (String orderNumber) {
                            samplingController.rxOrderNumberInput.value =
                                orderNumber;
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
                              samplingController.rxOrderFromDate.value,
                            ),
                            prefixStyle: TextStyle(
                              color: samplingController.rxOrderFromDate.value
                                      .isAtSameMomentAs(oldestDateTime)
                                  ? Colors.white
                                  : VardhmanColors.darkGrey,
                              fontSize: 13,
                            ),
                          ),
                          firstDate: samplingController.rxEarliestOrderDate.value,
                          lastDate: samplingController.rxOrderToDate.value,
                          value: samplingController.rxOrderFromDate.value,
                          onChanged: (DateTime? date) {
                            if (date != null) {
                              samplingController.rxOrderFromDate.value = date;
                              samplingController.rxDateRange.value = null;
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
                              samplingController.rxOrderToDate.value,
                            ),
                            prefixStyle: TextStyle(
                              color: VardhmanColors.darkGrey,
                              fontSize: 13,
                            ),
                          ),
                          firstDate: samplingController.rxOrderFromDate.value,
                          lastDate: DateTime.now(),
                          value: samplingController.rxOrderToDate.value,
                          onChanged: (DateTime? date) {
                            if (date != null) {
                              samplingController.rxOrderToDate.value = date;
                              samplingController.rxDateRange.value = null;
                            }
                          },
                        ),
                      ),
                      SizedBox(width: 8),
                      DateRangeMenu(filters: samplingController),
                    ],
                  ),
                  SizedBox(height: 8),
                  AdaptiveRow(
                    breakpoint: 440,
                    narrowLayout: NarrowLayout.wrap,
                    minChildWidth: 140,
                    children: <Widget>[
                      Flexible(
                        child: TextField(
                          controller: TextEditingController.fromValue(
                            TextEditingValue(
                              text: samplingController.rxMerchandiserInput.value,
                              selection: TextSelection.collapsed(
                                offset: samplingController
                                    .rxMerchandiserInput.value.length,
                              ),
                            ),
                          ),
                          onChanged: (String merchandiser) {
                            samplingController.rxMerchandiserInput.value =
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
                  AdaptiveRow(
                    breakpoint: 440,
                    narrowLayout: NarrowLayout.wrap,
                    minChildWidth: 140,
                    children: <Widget>[
                      Flexible(
                        child: TextField(
                          controller: TextEditingController.fromValue(
                            TextEditingValue(
                              text: samplingController.rxShadeInput.value,
                              selection: TextSelection.collapsed(
                                offset:
                                    samplingController.rxShadeInput.value.length,
                              ),
                            ),
                          ),
                          onChanged: (String value) {
                            samplingController.rxShadeInput.value = value;
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
                              text: samplingController.rxBuyerInput.value,
                              selection: TextSelection.collapsed(
                                offset:
                                    samplingController.rxBuyerInput.value.length,
                              ),
                            ),
                          ),
                          onChanged: (String value) {
                            samplingController.rxBuyerInput.value = value;
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
                ],
              ),
            ),
          ),
        ],
        );
      },
    );
  }
}
