import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/api/user_address.dart';
import 'package:vardhman_b2b/app/theme_variants.dart';
import 'package:vardhman_b2b/common/ship_to_selector.dart';
import 'package:vardhman_b2b/user/user_controller.dart';

UserAddress _address(int number, String city) => UserAddress(
      alphaName: 'Address $number',
      addressLine1: 'Plot $number',
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
    );

/// What ShipToBar reads, without the JDE calls the real controller makes.
class _FakeUserController extends GetxController implements UserController {
  _FakeUserController(List<UserAddress> addresses) {
    rxDeliveryAddresses.assignAll(addresses);
    rxDeliveryAddress.value = addresses.first;
  }

  @override
  final rxDeliveryAddresses = RxList<UserAddress>();

  @override
  final rxDeliveryAddress = Rxn<UserAddress>();

  @override
  Future<void> selectDeliveryAddress(UserAddress address) async =>
      rxDeliveryAddress.value = address;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  tearDown(Get.reset);

  Future<_FakeUserController> pumpBar(
    WidgetTester tester,
    List<UserAddress> addresses,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = Get.put<UserController>(
      _FakeUserController(addresses),
      tag: 'userController',
    ) as _FakeUserController;

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ShipToBar())),
    );

    return controller;
  }

  testWidgets('the arrow sits right after the selected address',
      (tester) async {
    await pumpBar(tester, [_address(0, 'Ludhiana'), _address(7, 'Tiruppur')]);

    final text = find.text('Address 0 · Plot 0 · Ludhiana, Punjab (Sold-To)');

    expect(text, findsOneWidget);

    final textRight = tester.getRect(text).right;

    final arrowLeft = tester.getRect(find.byIcon(Icons.arrow_drop_down)).left;

    // Next to the text, not at the bar's far end (1280 wide).
    expect(arrowLeft - textRight, lessThan(8));
    expect(
      tester.getRect(find.byIcon(Icons.arrow_drop_down)).right,
      lessThan(1280 - 100),
    );
  });

  testWidgets('picking an option changes the Ship-To', (tester) async {
    final controller = await pumpBar(
      tester,
      [_address(0, 'Ludhiana'), _address(7, 'Tiruppur')],
    );

    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();

    // The selected row is readable: theme-coloured text on a light tint,
    // not the dark highlight fill.
    final primary = ThemeVariants.current.primary;

    final selectedText = tester.widget<Text>(
      find
          .descendant(
            of: find.byType(PopupMenuItem<UserAddress>),
            matching:
                find.text('Address 0 · Plot 0 · Ludhiana, Punjab (Sold-To)'),
          )
          .last,
    );

    expect(selectedText.style!.color, primary);
    expect(find.byIcon(Icons.check), findsOneWidget);

    final highlight = tester.widgetList<Container>(
      find.descendant(
        of: find.byType(PopupMenuItem<UserAddress>),
        matching: find.byType(Container),
      ),
    );

    expect(
      highlight.where((container) => container.color == Colors.black),
      isEmpty,
    );

    await tester.tap(find.text('Address 7 · Plot 7 · Tiruppur, Punjab (7)'));
    await tester.pumpAndSettle();

    expect(controller.rxDeliveryAddress.value!.deliveryAddressNumber, 7);
    expect(
      find.text('Address 7 · Plot 7 · Tiruppur, Punjab (7)'),
      findsOneWidget,
    );
  });

  testWidgets('one address: shown, but the menu does not open', (tester) async {
    await pumpBar(tester, [_address(0, 'Ludhiana')]);

    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuItem<UserAddress>), findsNothing);
  });
}
