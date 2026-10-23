import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vardhman_b2b/api/api.dart';
import 'package:vardhman_b2b/api/user_address.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/drift/database.dart';
import 'package:vardhman_b2b/login/login_controller.dart';

class UserController extends GetxController {
  final _sharedPrefs = Get.find<SharedPreferences>();

  final loginController = Get.find<LoginController>();

  final Rx<UserDetail> rxCustomerDetail, rxUserDetail;

  final availableQuantity = 0.obs;

  final rxDeliveryAddress = Rxn<UserAddress>();

  final rxDeliveryAddresses = RxList<UserAddress>();

  UserController({
    required UserDetail userDetail,
    required UserDetail customerDetail,
  })  : rxCustomerDetail = customerDetail.obs,
        rxUserDetail = userDetail.obs {
    refreshDeliveryAddresses();
  }

  Future<void> refreshDeliveryAddresses() async {
    // Independent requests: run them together rather than one after another.
    final billingAddressFuture =
        Api.fetchBillingAddress(rxCustomerDetail.value.soldToNumber);

    final deliveryAddressesFuture = Api.fetchDeliveryAddresses(
      company: rxCustomerDetail.value.companyCode,
      soldToNumber: rxCustomerDetail.value.soldToNumber,
    );

    final billingAddress = await billingAddressFuture;

    final deliveryAddresses = await deliveryAddressesFuture;

    rxDeliveryAddresses.assignAll([
      if (billingAddress != null) billingAddress,
      ...deliveryAddresses,
    ]);

    Api.logShipTo(
        'Ship-To choices for ${rxCustomerDetail.value.soldToNumber}', {
      'soldToAddressFound': billingAddress != null,
      'deliveryAddressCount': deliveryAddresses.length,
      'choices': rxDeliveryAddresses
          .map((address) =>
              '${address.deliveryAddressNumber} ${address.alphaName.trim()}')
          .toList(),
    });

    if (rxDeliveryAddresses.isEmpty) {
      // No stale Ship-To from a previous Sold-To.
      rxDeliveryAddress.value = null;
    } else {
      String selectedAddressKey =
          sharedPrefsSelectedAddressKey(rxCustomerDetail.value);

      final selectedAddressJson = _sharedPrefs.getString(selectedAddressKey);

      if (selectedAddressJson != null) {
        rxDeliveryAddress.value = rxDeliveryAddresses.firstWhere(
          (element) => jsonEncode(element.toJson()) == selectedAddressJson,
          orElse: () => rxDeliveryAddresses.first,
        );
      } else {
        rxDeliveryAddress.value = rxDeliveryAddresses.first;
      }

      _sharedPrefs.setString(
        selectedAddressKey,
        jsonEncode(rxDeliveryAddress.value!.toJson()),
      );
    }
  }

  Future<void> selectDeliveryAddress(UserAddress newDeliveryAddress) async {
    String selectedAddressKey =
        sharedPrefsSelectedAddressKey(rxCustomerDetail.value);

    await _sharedPrefs.setString(
      selectedAddressKey,
      jsonEncode(newDeliveryAddress.toJson()),
    );

    rxDeliveryAddress.value = newDeliveryAddress;
  }

  Future<void> selectCustomer(String customerSoldToNumber) async {
    final customerDetailComp = await Api.fetchUserData(customerSoldToNumber);

    if (customerDetailComp != null) {
      rxCustomerDetail.value = UserDetail(
        soldToNumber: customerDetailComp.soldToNumber.value,
        isMobileUser: customerDetailComp.isMobileUser.value,
        mobileNumber: customerDetailComp.mobileNumber.value,
        canSendSMS: customerDetailComp.canSendSMS.value,
        email: customerDetailComp.email.value,
        whatsAppNumber: customerDetailComp.whatsAppNumber.value,
        canSendWhatsApp: customerDetailComp.canSendWhatsApp.value,
        name: customerDetailComp.name.value,
        companyCode: customerDetailComp.companyCode.value,
        companyName: customerDetailComp.companyName.value,
        role: customerDetailComp.role.value,
        category: customerDetailComp.category.value,
        discountPercent: customerDetailComp.discountPercent.value,
      );

      await _sharedPrefs.setString(
        sharedPrefsSelectedCustomerKey(rxUserDetail.value),
        customerSoldToNumber,
      );

      // Ship-To choices belong to the Sold-To.
      await refreshDeliveryAddresses();
    }
  }

  Future<void> logOut() async {
    loginController.lockUser();
  }

  /// JDE address number sent as Ship-To (order submit `ShipTo`, pricing
  /// `Ship_To`): the Sold-To itself when the Sold-To address is selected,
  /// otherwise the ORCH550101K `DeliveryAddressNumber`.
  String get shipToNumber {
    final deliveryAddressNumber =
        rxDeliveryAddress.value?.deliveryAddressNumber;

    return deliveryAddressNumber == null || deliveryAddressNumber == 0
        ? rxCustomerDetail.value.soldToNumber
        : deliveryAddressNumber.toString();
  }

  UserAddress? get _billingAddress => rxDeliveryAddresses.firstWhereOrNull(
        (userAddress) => userAddress.deliveryAddressNumber == 0,
      );

  String get branchPlant => _billingAddress?.branchPlant ?? '';

  String get branchPlantEmail => _billingAddress?.branchPlantEmail ?? '';

  String get branchPlantPhone => _billingAddress?.branchPlantPhone ?? '';

  String get branchPlantWhatsApp => _billingAddress?.branchPlantWhatsApp ?? '';
}
