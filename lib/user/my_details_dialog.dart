import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:toastification/toastification.dart';
import 'package:vardhman_b2b/api/user_address.dart';
import 'package:vardhman_b2b/app/theme_variants.dart';
import 'package:vardhman_b2b/bulk/bulk_controller.dart';
import 'package:vardhman_b2b/common/adaptive_dialog.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/drift/database.dart';
import 'package:vardhman_b2b/dtm/dtm_controller.dart';
import 'package:vardhman_b2b/invoices/invoices_controller.dart';
import 'package:vardhman_b2b/labdip/labdip_controller.dart';
import 'package:vardhman_b2b/login/login_controller.dart';
import 'package:vardhman_b2b/orders/orders_controller.dart';
import 'package:vardhman_b2b/sampling/sampling_controller.dart';
import 'package:vardhman_b2b/user/user_controller.dart';

/// The signed-in user's profile: who they are (from JDE at login), how to
/// reach them, the customer they act for (staff roles), a snapshot of their
/// orders and invoices as loaded in this session, their last payment and
/// their addresses. Read only. The header is drawn with the current theme's
/// backdrop (gradient, pattern, image), so it follows the theme.
class MyDetailsDialog extends StatelessWidget {
  const MyDetailsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final UserController userController = Get.find(tag: 'userController');

    final loginController = Get.find<LoginController>();

    return AdaptiveDialog(
      clipBehavior: Clip.antiAlias,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 760,
        child: Obx(
          () {
            final user = userController.rxUserDetail.value;

            final customer = userController.rxCustomerDetail.value;

            // Staff roles act for a customer picked after login.
            final isActingForCustomer =
                !isCustomer(user) && customer.soldToNumber != user.soldToNumber;

            final addresses = userController.rxDeliveryAddresses.toList();

            final selectedAddress = userController.rxDeliveryAddress.value;

            return Stack(
              children: <Widget>[
                SingleChildScrollView(
                  child: _Entrance(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _Hero(
                          user: user,
                          userId: loginController.rxUserId.value,
                        ),
                        // The stats float over the hero's lower edge; the
                        // cards below move up with them, so no gap is left
                        // under the stats (the shift shows as space above
                        // the footer instead).
                        Transform.translate(
                          offset: const Offset(0, -36),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: _Stats(customer: customer),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: _Columns(
                                  children: <Widget>[
                                    _Card(
                                      icon: Icons.contact_mail_outlined,
                                      title: 'Contact',
                                      children: <Widget>[
                                        _Detail(
                                          icon: Icons.alternate_email,
                                          label: 'Email',
                                          value: user.email,
                                          canCopy: true,
                                        ),
                                        _Detail(
                                          icon: Icons.phone_iphone_outlined,
                                          label: 'Mobile',
                                          value: user.mobileNumber,
                                          canCopy: true,
                                          tag: user.mobileNumber.trim().isEmpty
                                              ? null
                                              : _Tag.alerts(
                                                  'SMS', user.canSendSMS),
                                        ),
                                        _Detail(
                                          icon: Icons.chat_outlined,
                                          label: 'WhatsApp',
                                          value: user.whatsAppNumber,
                                          canCopy: true,
                                          tag:
                                              user.whatsAppNumber.trim().isEmpty
                                                  ? null
                                                  : _Tag.alerts(
                                                      'Alerts',
                                                      user.canSendWhatsApp,
                                                    ),
                                        ),
                                      ],
                                    ),
                                    if (isActingForCustomer)
                                      _Card(
                                        icon: Icons.storefront_outlined,
                                        title: 'Acting for customer',
                                        children: <Widget>[
                                          _Detail(
                                            icon: Icons.badge_outlined,
                                            label: 'Name',
                                            value: customer.name,
                                          ),
                                          _Detail(
                                            icon: Icons.tag,
                                            label: 'Customer No.',
                                            value: customer.soldToNumber,
                                            canCopy: true,
                                          ),
                                          _Detail(
                                            icon: Icons.apartment_outlined,
                                            label: 'Company',
                                            value: _join([
                                              customer.companyName,
                                              customer.companyCode,
                                            ]),
                                          ),
                                          _Detail(
                                            icon: Icons.alternate_email,
                                            label: 'Email',
                                            value: customer.email,
                                            canCopy: true,
                                          ),
                                          _Detail(
                                            icon: Icons.phone_iphone_outlined,
                                            label: 'Mobile',
                                            value: customer.mobileNumber,
                                            canCopy: true,
                                          ),
                                        ],
                                      ),
                                    const _LastPaymentCard(),
                                    if (userController.branchPlant.isNotEmpty)
                                      _Card(
                                        icon: Icons.factory_outlined,
                                        title: 'Your Vardhman branch',
                                        children: <Widget>[
                                          _Detail(
                                            icon: Icons.location_city_outlined,
                                            label: 'Branch',
                                            value: userController.branchPlant,
                                          ),
                                          _Detail(
                                            icon: Icons.alternate_email,
                                            label: 'Email',
                                            value:
                                                userController.branchPlantEmail,
                                            canCopy: true,
                                          ),
                                          _Detail(
                                            icon: Icons.call_outlined,
                                            label: 'Phone',
                                            value:
                                                userController.branchPlantPhone,
                                            canCopy: true,
                                          ),
                                          _Detail(
                                            icon: Icons.chat_outlined,
                                            label: 'WhatsApp',
                                            value: userController
                                                .branchPlantWhatsApp,
                                            canCopy: true,
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                              if (addresses.isNotEmpty)
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: _Addresses(
                                    addresses: addresses,
                                    selected: selectedAddress,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        _Footer(),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.white.withAlpha(40),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: Get.back,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Fades and slides the profile in when the dialog opens.
class _Entrance extends StatelessWidget {
  const _Entrance({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Theme backdrop with the avatar, name, chips and company.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.user,
    required this.userId,
  });

  final UserDetail user;

  final String userId;

  @override
  Widget build(BuildContext context) {
    final variant = ThemeVariants.current;

    return ThemeBackdrop(
      variant: variant,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      child: Stack(
        children: <Widget>[
          // Soft glow of the brand colour behind the avatar.
          Positioned(
            left: -60,
            top: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    variant.primary.withAlpha(110),
                    variant.primary.withAlpha(0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 56, 64),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 20,
              runSpacing: 16,
              children: <Widget>[
                _Avatar(name: user.name),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'MY DETAILS',
                        style: TextStyle(
                          color: Colors.white.withAlpha(180),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.name.trim().isEmpty ? 'User' : user.name.trim(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _join([
                          user.companyName,
                          if (userId.trim().isNotEmpty) 'ID $userId',
                        ]),
                        style: TextStyle(
                          color: Colors.white.withAlpha(210),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          if (user.role.trim().isNotEmpty)
                            _HeroChip(
                              icon: Icons.verified_user_outlined,
                              text: _titleCase(user.role),
                            ),
                          if (user.category.trim().isNotEmpty)
                            _HeroChip(
                              icon: Icons.workspace_premium_outlined,
                              text: 'Category ${user.category.trim()}',
                            ),
                          _HeroChip(
                            icon: user.isMobileUser
                                ? Icons.phone_android
                                : Icons.language,
                            text: user.isMobileUser
                                ? 'Mobile app user'
                                : 'Web portal user',
                          ),
                          if (user.companyCode.trim().isNotEmpty)
                            _HeroChip(
                              icon: Icons.apartment_outlined,
                              text: 'Company ${user.companyCode.trim()}',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final variant = ThemeVariants.current;

    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withAlpha(230),
        boxShadow: [
          BoxShadow(
            color: variant.primary.withAlpha(120),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Container(
        width: 84,
        height: 84,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: variant.primaryFill(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Text(
          initials.isEmpty ? '?' : initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

/// Frosted chip on the hero.
class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.text});

  final IconData icon;

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(36),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Orders, open and overdue invoices and the discount, as loaded in this
/// session.
class _Stats extends StatelessWidget {
  const _Stats({required this.customer});

  final UserDetail customer;

  @override
  Widget build(BuildContext context) {
    final orders = _OrderCounts.read();

    final invoicesController = Get.isRegistered<InvoicesController>()
        ? Get.find<InvoicesController>()
        : null;

    final isLoadingInvoices = invoicesController?.isLoading ?? false;

    final openCount = invoicesController?.openInvoices.length ?? 0;

    final overdueCount = invoicesController?.overdueInvoices.length ?? 0;

    final overdueAmount = invoicesController?.totalOverdueAmount ?? 0;

    final tiles = <Widget>[
      _StatTile(
        icon: Icons.inventory_2_outlined,
        value: '${orders.total}',
        label: 'Orders',
        detail: orders.breakdown,
      ),
      _StatTile(
        icon: Icons.receipt_long_outlined,
        value: isLoadingInvoices
            ? '…'
            : _rupees(invoicesController?.totalOpenAmount ?? 0),
        label: 'Total due',
        detail: '$openCount open invoice${openCount == 1 ? '' : 's'}',
      ),
      _StatTile(
        icon: Icons.warning_amber_rounded,
        value: isLoadingInvoices ? '…' : _rupees(overdueAmount),
        label: 'Overdue',
        detail: overdueAmount <= 0
            ? 'Nothing overdue'
            : overdueCount == 0
                ? 'Pay now to avoid charges'
                : '$overdueCount invoice${overdueCount == 1 ? '' : 's'}',
        color: overdueAmount > 0 ? VardhmanColors.error : VardhmanColors.green,
      ),
      _StatTile(
        icon: Icons.local_offer_outlined,
        value: _percent(customer.discountPercent),
        label: 'Early-pay discount',
        // As applied in _getDiscountedAmount (invoice_info.dart).
        detail: 'Paid within 7 days of invoice',
        color: VardhmanColors.green,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;

        // Four across when there is room, else two by two; the tiles of a
        // row share its height.
        final perRow = constraints.maxWidth >= 600 ? 4 : 2;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: gap,
          children: <Widget>[
            for (var start = 0; start < tiles.length; start += perRow)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: gap,
                  children: <Widget>[
                    for (final tile in tiles.skip(start).take(perRow))
                      Expanded(child: tile),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Order totals by kind, from the controllers loaded at login.
class _OrderCounts {
  const _OrderCounts(this.total, this.breakdown);

  final int total;

  final String breakdown;

  static _OrderCounts read() {
    int count<T extends GetxController>(int Function(T) read) =>
        Get.isRegistered<T>() ? read(Get.find<T>()) : 0;

    final total = count<OrdersController>((c) => c.rxOrderHeaderLines.length);

    final drafts = count<SamplingController>((c) => c.rxDraftOrders.length) +
        count<LabdipController>((c) => c.rxDraftOrders.length) +
        count<DtmController>((c) => c.rxDraftOrders.length) +
        count<BulkController>((c) => c.rxDraftOrders.length);

    final parts = <String>[
      for (final (label, value) in [
        ('Sampling', count<SamplingController>((c) => c.samplingOrders.length)),
        ('Labdip', count<LabdipController>((c) => c.labdipOrders.length)),
        ('DTM', count<DtmController>((c) => c.dtmOrders.length)),
        ('Bulk', count<BulkController>((c) => c.bulkOrders.length)),
      ])
        if (value > 0) '$value $label',
      if (drafts > 0) '$drafts draft${drafts == 1 ? '' : 's'}',
    ];

    return _OrderCounts(
      total,
      parts.isEmpty ? 'None yet' : parts.join(' · '),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.detail,
    this.color,
  });

  final IconData icon;

  final String value, label, detail;

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? VardhmanColors.red;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tint.withAlpha(40)),
        boxShadow: [
          BoxShadow(
            color: VardhmanColors.darkGrey.withAlpha(22),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: tint.withAlpha(28),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: tint),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: VardhmanColors.darkGrey.withAlpha(180),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color ?? VardhmanColors.darkGrey,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: VardhmanColors.darkGrey.withAlpha(150),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two columns of cards on a wide dialog, one on a narrow one.
class _Columns extends StatelessWidget {
  const _Columns({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // No empty slot for a last payment that is not there.
    final cards = children
        .where((child) => child is! _LastPaymentCard || child.hasPayment)
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;

        if (constraints.maxWidth < 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: gap,
            children: cards,
          );
        }

        // Each card goes to the shorter column so far, measured in rows
        // (header + details), keeping the columns about even.
        final left = <Widget>[], right = <Widget>[];

        var leftRows = 0, rightRows = 0;

        for (final card in cards) {
          final rows = switch (card) {
            _Card(:final children) => children.length + 1,
            _LastPaymentCard() => 5,
            _ => 3,
          };

          if (leftRows <= rightRows) {
            left.add(card);
            leftRows += rows;
          } else {
            right.add(card);
            rightRows += rows;
          }
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: gap,
                children: left,
              ),
            ),
            const SizedBox(width: gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: gap,
                children: right,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;

  final String title;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VardhmanColors.dividerGrey),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: VardhmanColors.dividerGrey.withAlpha(110),
            ),
            child: Row(
              children: <Widget>[
                Icon(icon, size: 18, color: VardhmanColors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: VardhmanColors.darkGrey,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// One labelled value with an icon; empty values show as a dash. With
/// [canCopy], a button copies the value.
class _Detail extends StatelessWidget {
  const _Detail({
    required this.icon,
    required this.label,
    required this.value,
    this.canCopy = false,
    this.tag,
  });

  final IconData icon;

  final String label, value;

  final bool canCopy;

  final Widget? tag;

  @override
  Widget build(BuildContext context) {
    final text = value.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: VardhmanColors.darkGrey.withAlpha(140)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: VardhmanColors.darkGrey.withAlpha(150),
                  ),
                ),
                const SizedBox(height: 1),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: <Widget>[
                    SelectableText(
                      text.isEmpty ? '—' : text,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: VardhmanColors.darkGrey,
                      ),
                    ),
                    if (tag != null && text.isNotEmpty) tag!,
                  ],
                ),
              ],
            ),
          ),
          if (canCopy && text.isNotEmpty)
            IconButton(
              tooltip: 'Copy $label',
              visualDensity: VisualDensity.compact,
              iconSize: 16,
              color: VardhmanColors.darkGrey.withAlpha(150),
              icon: const Icon(Icons.copy_rounded),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));

                toastification.show(
                  autoCloseDuration: const Duration(seconds: 2),
                  primaryColor: VardhmanColors.green,
                  title: Text('$label copied'),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Small coloured label next to a value.
class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);

  /// "SMS on" / "SMS off".
  _Tag.alerts(String channel, bool isOn)
      : this(
          '$channel ${isOn ? 'on' : 'off'}',
          isOn ? VardhmanColors.green : VardhmanColors.darkGrey.withAlpha(150),
        );

  final String text;

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// The last invoice payment started from this browser, if any.
class _LastPaymentCard extends StatelessWidget {
  const _LastPaymentCard();

  Map<String, dynamic>? get _payment => Get.isRegistered<InvoicesController>()
      ? Get.find<InvoicesController>().rxLastPayment.value
      : null;

  bool get hasPayment => _payment != null;

  @override
  Widget build(BuildContext context) {
    final payment = _payment;

    if (payment == null) {
      return const SizedBox.shrink();
    }

    final invoices =
        (payment['invoices'] as List? ?? []).cast<Map<String, dynamic>>();

    final amount = invoices.fold<double>(
      0,
      (sum, invoice) =>
          sum + ((invoice['paymentAmount'] as num?)?.toDouble() ?? 0),
    );

    final date = DateTime.tryParse('${payment['date']}');

    return _Card(
      icon: Icons.payments_outlined,
      title: 'Last payment',
      children: <Widget>[
        _Detail(
          icon: Icons.confirmation_number_outlined,
          label: 'Receipt',
          value: '${payment['receiptNumber'] ?? ''}',
          canCopy: true,
        ),
        _Detail(
          icon: Icons.currency_rupee,
          label: 'Amount',
          value: _rupees(amount, compact: false),
        ),
        _Detail(
          icon: Icons.event_outlined,
          label: 'Started',
          value:
              date == null ? '' : DateFormat('dd MMM yyyy, HH:mm').format(date),
        ),
        _Detail(
          icon: Icons.receipt_outlined,
          label: 'Invoices',
          value: '${invoices.length}',
        ),
      ],
    );
  }
}

/// Billing and delivery addresses as cards; the selected Ship-To stands out.
class _Addresses extends StatelessWidget {
  const _Addresses({
    required this.addresses,
    required this.selected,
  });

  final List<UserAddress> addresses;

  final UserAddress? selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: <Widget>[
              Icon(Icons.local_shipping_outlined,
                  size: 18, color: VardhmanColors.red),
              const SizedBox(width: 8),
              Text(
                'Addresses',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: VardhmanColors.darkGrey,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${addresses.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: VardhmanColors.darkGrey.withAlpha(150),
                ),
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 12.0;

            final perRow = constraints.maxWidth >= 600 ? 2 : 1;

            final width = (constraints.maxWidth - gap * (perRow - 1)) / perRow;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final address in addresses)
                  SizedBox(
                    width: width,
                    child: _AddressCard(
                      address: address,
                      isSelected: address == selected,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.isSelected,
  });

  final UserAddress address;

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final isBilling = address.deliveryAddressNumber == 0;

    final lines = [
      address.addressLine1,
      address.addressLine2,
      address.addressLine3,
      address.addressLine4,
      _join([address.city, address.postalCode], ' '),
      _join([address.state, address.country], ', '),
    ].map((line) => line.trim()).where((line) => line.isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSelected
            ? VardhmanColors.red.withAlpha(14)
            : VardhmanColors.dividerGrey.withAlpha(70),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? VardhmanColors.red : VardhmanColors.dividerGrey,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                isBilling ? Icons.home_work_outlined : Icons.place_outlined,
                size: 16,
                color: isSelected
                    ? VardhmanColors.red
                    : VardhmanColors.darkGrey.withAlpha(160),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  address.alphaName.trim().isEmpty
                      ? (isBilling ? 'Billing address' : 'Delivery address')
                      : address.alphaName.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: VardhmanColors.darkGrey,
                  ),
                ),
              ),
              if (isBilling) ...[
                const SizedBox(width: 6),
                _Tag('Billing', VardhmanColors.darkGrey),
              ],
              if (isSelected) ...[
                const SizedBox(width: 6),
                _Tag('Ship-To', VardhmanColors.red),
              ],
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            lines.join('\n'),
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: VardhmanColors.darkGrey.withAlpha(200),
            ),
          ),
          if (address.stateCode.trim().isNotEmpty || !isBilling) ...[
            const SizedBox(height: 8),
            Text(
              _join([
                if (!isBilling) 'Address No. ${address.deliveryAddressNumber}',
                if (address.stateCode.trim().isNotEmpty)
                  'State code ${address.stateCode.trim()}',
              ]),
              style: TextStyle(
                fontSize: 11,
                color: VardhmanColors.darkGrey.withAlpha(140),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final variant = ThemeVariants.current;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: VardhmanColors.dividerGrey.withAlpha(90),
      child: Row(
        children: <Widget>[
          Icon(variant.icon, size: 14, color: VardhmanColors.red),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Vardhman B2B Portal v2.0 · ${variant.name} theme · '
              'Details as held in JDE',
              style: TextStyle(
                fontSize: 11,
                color: VardhmanColors.darkGrey.withAlpha(160),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _join(List<String> parts, [String separator = ' · ']) => parts
    .map((part) => part.trim())
    .where((part) => part.isNotEmpty)
    .join(separator);

String _titleCase(String text) => text
    .trim()
    .toLowerCase()
    .split(RegExp(r'[\s_]+'))
    .where((word) => word.isNotEmpty)
    .map((word) => word[0].toUpperCase() + word.substring(1))
    .join(' ');

String _percent(double value) =>
    '${value == value.roundToDouble() ? value.toStringAsFixed(0) : value}%';

/// ₹ amount, in lakh above one lakh when [compact].
String _rupees(double amount, {bool compact = true}) {
  if (compact && amount.abs() >= 100000) {
    return '₹${(amount / 100000).toStringAsFixed(2)} L';
  }

  return '₹${NumberFormat('#,##,##0', 'en_IN').format(amount)}';
}
