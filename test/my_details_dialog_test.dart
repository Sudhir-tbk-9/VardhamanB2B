import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/api/user_address.dart';
import 'package:vardhman_b2b/drift/database.dart';
import 'package:vardhman_b2b/login/login_controller.dart';
import 'package:vardhman_b2b/user/my_details_dialog.dart';
import 'package:vardhman_b2b/user/user_controller.dart';

UserDetail _userDetail({
  required String soldToNumber,
  required String name,
  required String role,
}) =>
    UserDetail(
      soldToNumber: soldToNumber,
      isMobileUser: false,
      mobileNumber: '9800000000',
      canSendSMS: true,
      whatsAppNumber: '',
      canSendWhatsApp: false,
      email: 'buyer@example.com',
      name: name,
      companyCode: '10901',
      companyName: 'Vardhman Yarns',
      role: role,
      category: 'A',
      discountPercent: 3,
    );

UserAddress _address(int number, String city) => UserAddress(
      alphaName: 'Address $number',
      addressLine1: 'Plot $number, Industrial Area',
      addressLine2: '',
      addressLine3: '',
      addressLine4: '',
      city: city,
      postalCode: '141001',
      state: 'Punjab',
      stateCode: 'PB',
      country: 'India',
      countryCode: 'IN',
      deliveryAddressNumber: number,
      branchPlant: number == 0 ? 'LUDHIANA' : null,
    );

/// What MyDetailsDialog reads, without the JDE calls the real controller
/// makes.
class _FakeUserController extends GetxController implements UserController {
  _FakeUserController(UserDetail user, UserDetail customer)
      : rxUserDetail = user.obs,
        rxCustomerDetail = customer.obs;

  @override
  final Rx<UserDetail> rxUserDetail, rxCustomerDetail;

  @override
  final rxDeliveryAddresses = RxList<UserAddress>([
    _address(0, 'Ludhiana'),
    _address(7, 'Tiruppur'),
    _address(8, 'Noida'),
  ]);

  @override
  late final rxDeliveryAddress = Rxn<UserAddress>(rxDeliveryAddresses[2]);

  @override
  String get branchPlant => 'LUDHIANA';

  @override
  String get branchPlantEmail => 'ludhiana@example.com';

  @override
  String get branchPlantPhone => '';

  @override
  String get branchPlantWhatsApp => '';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeLoginController extends GetxController implements LoginController {
  @override
  final rxUserId = 'CUST01'.obs;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> _open(
  WidgetTester tester,
  Size size, {
  required UserDetail user,
  required UserDetail customer,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  Get.put<UserController>(
    _FakeUserController(user, customer),
    tag: 'userController',
  );
  Get.put<LoginController>(_FakeLoginController());
  addTearDown(Get.reset);

  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: MyDetailsDialog())),
  );
}

void main() {
  final customer =
      _userDetail(soldToNumber: '105960', name: 'ACME KNITS', role: 'CUSTOMER');

  final staff =
      _userDetail(soldToNumber: 'R SHARMA', name: 'R SHARMA', role: 'SALES');

  for (final MapEntry(key: name, value: size) in const {
    'phone': Size(360, 640),
    'desktop': Size(1440, 900),
  }.entries) {
    testWidgets('customer, $name: details shown, no overflow', (tester) async {
      await _open(tester, size, user: customer, customer: customer);

      expect(find.text('MY DETAILS'), findsOneWidget);
      expect(find.text('ACME KNITS'), findsOneWidget);
      expect(find.text('AK'), findsOneWidget);
      expect(find.text('Vardhman Yarns · ID CUST01'), findsOneWidget);
      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('Category A'), findsOneWidget);
      expect(find.text('Web portal user'), findsOneWidget);

      expect(find.text('9800000000'), findsOneWidget);
      expect(find.text('SMS on'), findsOneWidget);
      // The empty WhatsApp number shows as a dash, without an alerts tag.
      expect(find.text('—'), findsWidgets);
      expect(find.text('Alerts off'), findsNothing);

      expect(find.text('3%'), findsOneWidget);
      expect(find.text('Paid within 7 days of invoice'), findsOneWidget);

      // A customer is not acting for anyone else.
      expect(find.text('Acting for customer'), findsNothing);
      // No payment started from this browser.
      expect(find.text('Last payment'), findsNothing);

      expect(find.text('Addresses'), findsOneWidget);
      expect(find.text('Billing'), findsOneWidget);
      expect(find.text('Your Vardhman branch'), findsOneWidget);
    });

    testWidgets('staff acting for a customer, $name', (tester) async {
      await _open(tester, size, user: staff, customer: customer);

      expect(find.text('Sales'), findsOneWidget);
      expect(find.text('Acting for customer'), findsOneWidget);
      expect(find.text('105960'), findsOneWidget);
    });
  }

  testWidgets('marks the selected delivery address as Ship-To', (
    tester,
  ) async {
    await _open(
      tester,
      const Size(1440, 900),
      user: customer,
      customer: customer,
    );

    final shipTo = find.text('Ship-To');
    expect(shipTo, findsOneWidget);

    final card = find.ancestor(
      of: shipTo,
      matching: find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_AddressCard',
      ),
    );
    expect(
      find.descendant(of: card, matching: find.textContaining('Noida')),
      findsOneWidget,
    );
  });
}
