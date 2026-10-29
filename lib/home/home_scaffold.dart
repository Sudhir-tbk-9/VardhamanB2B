import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';
import 'package:vardhman_b2b/api/api.dart';
import 'package:vardhman_b2b/app/theme_switcher.dart';
import 'package:vardhman_b2b/common/header_view.dart';
import 'package:vardhman_b2b/common/new_order_date_field.dart';
import 'package:vardhman_b2b/common/new_order_text_field.dart';
import 'package:vardhman_b2b/common/primary_button.dart';
import 'package:vardhman_b2b/common/secondary_button.dart';
import 'package:vardhman_b2b/app/theme_variants.dart';
import 'package:vardhman_b2b/common/adaptive_dialog.dart';
import 'package:vardhman_b2b/common/breakpoints.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/home/home_controller.dart';
import 'package:vardhman_b2b/home/lazy_indexed_stack.dart';
import 'package:vardhman_b2b/home/nav_rail.dart';
import 'package:vardhman_b2b/bulk/bulk_view.dart';
import 'package:vardhman_b2b/dtm/dtm_view.dart';
import 'package:vardhman_b2b/home/order_summary_controller.dart';
import 'package:vardhman_b2b/home/order_summary_view.dart';
import 'package:vardhman_b2b/labdip/labdip_view.dart';
import 'package:vardhman_b2b/open/open_view.dart';
import 'package:vardhman_b2b/paid/paid_view.dart';
import 'package:vardhman_b2b/sampling/sampling_view.dart';
import 'package:vardhman_b2b/user/my_details_dialog.dart';
import 'package:vardhman_b2b/user/user_controller.dart';

/// Entries of the account menu behind the header's three-dot button.
enum _AccountMenuItem { orderSummary, statusReport, theme, myDetails, logout }

class HomeScaffold extends StatefulWidget {
  const HomeScaffold({
    super.key,
    required this.tabIndex,
  });

  /// Nav rail index of the tab shown, taken from the URL (see appRouter).
  final int tabIndex;

  @override
  State<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<HomeScaffold> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();

    _syncNavRailIndex();
  }

  @override
  void didUpdateWidget(HomeScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);

    _syncNavRailIndex();
  }

  /// The URL decides the tab; rxNavRailIndex mirrors it for code that reads
  /// the current tab, such as the payment dialogs saving where to come back
  /// to.
  void _syncNavRailIndex() {
    Get.find<HomeController>().rxNavRailIndex.value = widget.tabIndex;
  }

  Future<void> _onAccountMenuSelected(_AccountMenuItem item) async {
    final UserController userController = Get.find(tag: 'userController');

    switch (item) {
      case _AccountMenuItem.orderSummary:
        _openOrderSummary();
      case _AccountMenuItem.statusReport:
        await _openStatusReport(userController);
      case _AccountMenuItem.theme:
        Get.dialog(const ThemeSwitcherDialog());
      case _AccountMenuItem.myDetails:
        Get.dialog(const MyDetailsDialog());
      case _AccountMenuItem.logout:
        await userController.logOut();
    }
  }

  void _openOrderSummary() {
    if (Get.isRegistered<OrderSummaryController>()) {
      Get.delete<OrderSummaryController>();
    }

    Get.put(
      OrderSummaryController(),
    );
    Get.dialog(
      const AdaptiveDialog(
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: 1000,
          child: OrderSummaryView(),
        ),
      ),
    );
  }

  Future<void> _openStatusReport(UserController userController) async {
    final HomeController homeController = Get.find();

    var email = await Api.fetchReportEmailAddress(
        userController.rxUserDetail.value.soldToNumber);
    homeController.rxEmail.value = email;
    Get.dialog(
      AdaptiveDialog(
        insetPadding: EdgeInsets.all(80),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              HeaderView(
                elevation: 4,
                leading: SecondaryButton(
                  wait: false,
                  iconData: Icons.arrow_back_ios_new,
                  text: 'Back',
                  onPressed: () async {
                    Get.back();
                  },
                ),
                title: Text(
                  'Request Status Report',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                trailing: DefaultTextStyle(
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                  child: Obx(
                    () => PrimaryButton(
                      text: 'Submit',
                      onPressed: homeController.rxEmail.isEmpty ||
                              !RegExp(
                                r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                              ).hasMatch(
                                homeController.rxEmail.value,
                              )
                          ? null
                          : () async {
                              Api.submitStatusReport(
                                email: homeController.rxEmail.value,
                                fromDate: homeController.rxFromDate.value!,
                                soldToNumber: userController
                                    .rxUserDetail.value.soldToNumber,
                              );

                              Get.back();

                              toastification.show(
                                autoCloseDuration: Duration(seconds: 3),
                                primaryColor: VardhmanColors.green,
                                title: Text('Request Submitted!'),
                              );
                            },
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    NewOrderTextField(
                        labelText: 'Email', rxString: homeController.rxEmail),
                    SizedBox(
                      height: 16,
                    ),
                    NewOrderDateField(
                      labelText: 'From',
                      rxDate: homeController.rxFromDate,
                      firstDate: homeController.rxFromDate.value?.subtract(
                        Duration(days: 60),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Top of the account menu: the user on the current theme's backdrop. Not
  /// selectable.
  PopupMenuItem<_AccountMenuItem> _accountMenuHeader(
    UserController userController,
  ) {
    final variant = ThemeVariants.current;

    final user = userController.rxUserDetail.value;

    final initials = user.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();

    return PopupMenuItem(
      enabled: false,
      padding: EdgeInsets.zero,
      child: ThemeBackdrop(
        variant: variant,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: variant.primaryFill(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.white.withAlpha(160)),
                ),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.companyName.isEmpty
                          ? user.soldToNumber
                          : '${user.companyName} · ${user.soldToNumber}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withAlpha(200),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One account menu option: its icon in a chip tinted with the theme's
  /// primary colour, or with [color] (Logout).
  PopupMenuItem<_AccountMenuItem> _accountMenuEntry(
    _AccountMenuItem value,
    IconData icon,
    String text, {
    Color? color,
  }) {
    final tint = color ?? VardhmanColors.red;

    return PopupMenuItem(
      value: value,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tint.withAlpha(26),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: tint),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: color ?? VardhmanColors.darkGrey,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UserController userController = Get.find(tag: 'userController');

    // Phone sized: the nav rail moves into a drawer opened from the header.
    final isCompact = context.isCompact;

    return Scaffold(
      key: _scaffoldKey,
      drawer: isCompact
          ? Drawer(
              width: 120,
              shape: const RoundedRectangleBorder(),
              child: NavRail(
                selectedIndex: widget.tabIndex,
                onSelected: () => _scaffoldKey.currentState?.closeDrawer(),
              ),
            )
          : null,
      body: Obx(
        () => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (!isCompact) NavRail(selectedIndex: widget.tabIndex),
            Expanded(
              child: Column(
                children: <Widget>[
                  ThemeBackdrop(
                    variant: ThemeVariants.current,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    child: Container(
                      height: 50,
                      padding: EdgeInsets.only(right: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (isCompact)
                            IconButton(
                              tooltip: 'Menu',
                              icon: const Icon(
                                Icons.menu,
                                color: Colors.white,
                              ),
                              onPressed: () =>
                                  _scaffoldKey.currentState?.openDrawer(),
                            ),
                          Flexible(
                            child: Text(
                              isCompact
                                  ? 'Vardhman B2B'
                                  : 'Vardhman B2B Portal v2.0',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Welcome and the account menu kept together on
                          // the right. The menu opens on click only.
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Welcome! ${userController.rxUserDetail.value.name}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                PopupMenuButton<_AccountMenuItem>(
                                  tooltip: 'Menu',
                                  icon: const Icon(
                                    Icons.more_vert,
                                    color: Colors.white,
                                  ),
                                  position: PopupMenuPosition.under,
                                  color: Colors.white,
                                  surfaceTintColor: Colors.transparent,
                                  elevation: 8,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  // The header strip runs to the menu's edges.
                                  clipBehavior: Clip.antiAlias,
                                  menuPadding: const EdgeInsets.only(bottom: 6),
                                  constraints:
                                      const BoxConstraints(minWidth: 260),
                                  popUpAnimationStyle: const AnimationStyle(
                                    duration: Duration(milliseconds: 150),
                                    reverseDuration:
                                        Duration(milliseconds: 100),
                                  ),
                                  onSelected: _onAccountMenuSelected,
                                  itemBuilder: (context) => [
                                    _accountMenuHeader(userController),
                                    const PopupMenuDivider(height: 6),
                                    if (userController
                                            .rxUserDetail.value.role !=
                                        'CUSTOMER')
                                      _accountMenuEntry(
                                        _AccountMenuItem.orderSummary,
                                        Icons.summarize_outlined,
                                        'Order Summary',
                                      ),
                                    _accountMenuEntry(
                                      _AccountMenuItem.statusReport,
                                      Icons.assignment_outlined,
                                      'Status Report',
                                    ),
                                    _accountMenuEntry(
                                      _AccountMenuItem.theme,
                                      Icons.palette_outlined,
                                      'Theme',
                                    ),
                                    _accountMenuEntry(
                                      _AccountMenuItem.myDetails,
                                      Icons.account_circle_outlined,
                                      'My Details',
                                    ),
                                    const PopupMenuDivider(),
                                    _accountMenuEntry(
                                      _AccountMenuItem.logout,
                                      Icons.logout,
                                      'Logout',
                                      color: VardhmanColors.red,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    // Order matches the nav rail indexes: 0–3 orders,
                    // 4–5 payments (see NavRail).
                    child: LazyIndexedStack(
                      index: widget.tabIndex,
                      children: const <Widget>[
                        SamplingView(),
                        LabdipView(),
                        DtmView(),
                        BulkView(),
                        OpenView(),
                        PaidView(),
                      ],
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
