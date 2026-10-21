import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';
import 'package:vardhman_b2b/api/api.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/drift/database.dart';
import 'package:vardhman_b2b/user/user_controller.dart';

class OrderReviewController extends GetxController {
  final _userController = Get.find<UserController>(tag: 'userController');

  final rxOrderNumber = Rxn<int>();

  final rxIsProcessing = false.obs;

  final rxUomDescriptionMap = <String, String>{}.obs;

  OrderReviewController() {
    fetchDraftOrderNumber();

    Api.fetchUoMDescriptions().then(
      (uomDescMap) {
        rxUomDescriptionMap.assignAll(uomDescMap);
      },
    );
  }

  void fetchDraftOrderNumber() {
    Api.fetchDraftOrderNumber().then(
      (newOrderNumber) {
        if (newOrderNumber != null) {
          rxOrderNumber.value = newOrderNumber;
        }
      },
    );
  }

  String getUomDescription(String uom) {
    return rxUomDescriptionMap.containsKey(uom)
        ? rxUomDescriptionMap[uom]!
        : '';
  }

  Future<bool> submitLabdipOrder({
    required String merchandiserName,
    required String b2bOrderNumber,
    required List<DraftTableData> labdipOrderLines,
  }) async {
    bool isSubmitted = false;

    isSubmitted = await Api.submitLabdipOrder(
      b2bOrderNumber: b2bOrderNumber,
      merchandiserName: merchandiserName,
      branchPlant: _userController.branchPlant,
      soldTo: _userController.rxCustomerDetail.value.soldToNumber,
      shipTo: _userController.shipToNumber,
      company: _userController.rxCustomerDetail.value.companyCode,
      orderTakenBy: _userController.rxUserDetail.value.role,
      labdipOrderLines: labdipOrderLines,
    );

    rxIsProcessing.value = false;

    if (isSubmitted) {
      toastification.show(
        autoCloseDuration: Duration(minutes: 15),
        primaryColor: VardhmanColors.green,
        title: Text(
          'Order $b2bOrderNumber placed successfully!',
        ),
      );

      if (_userController.rxCustomerDetail.value.canSendSMS) {
        Api.sendOrderEntrySMS(
          orderNumber: b2bOrderNumber,
          mobileNumber: _userController.rxCustomerDetail.value.mobileNumber,
        );
      }

      if (_userController.rxCustomerDetail.value.canSendWhatsApp) {
        Api.sendOrderEntryWhatsApp(
          orderNumber: b2bOrderNumber,
          mobileNumber: _userController.rxCustomerDetail.value.mobileNumber,
        );
      }

      fetchDraftOrderNumber();
    } else {
      toastification.show(
        autoCloseDuration: Duration(seconds: 3),
        primaryColor: VardhmanColors.red,
        title: Text(
          'Some error placing the order!',
        ),
      );
    }

    return isSubmitted;
  }

  Future<bool> submitSamplingOrder({
    required String merchandiserName,
    required String b2bOrderNumber,
    required List<DraftTableData> samplingOrderLines,
  }) async {
    bool isSubmitted = false;

    isSubmitted = await Api.submitSamplingOrder(
      b2bOrderNumber: b2bOrderNumber,
      merchandiserName: merchandiserName,
      branchPlant: _userController.branchPlant,
      soldTo: _userController.rxCustomerDetail.value.soldToNumber,
      shipTo: _userController.shipToNumber,
      company: _userController.rxCustomerDetail.value.companyCode,
      orderTakenBy: _userController.rxUserDetail.value.role,
      samplingOrderLines: samplingOrderLines,
    );

    rxIsProcessing.value = false;

    if (isSubmitted) {
      toastification.show(
        autoCloseDuration: Duration(minutes: 15),
        primaryColor: VardhmanColors.green,
        title: Text(
          'Order $b2bOrderNumber placed successfully!',
        ),
      );

      if (_userController.rxCustomerDetail.value.canSendSMS) {
        Api.sendOrderEntrySMS(
          orderNumber: b2bOrderNumber,
          mobileNumber: _userController.rxCustomerDetail.value.mobileNumber,
        );
      }

      if (_userController.rxCustomerDetail.value.canSendWhatsApp) {
        Api.sendOrderEntryWhatsApp(
          orderNumber: b2bOrderNumber,
          mobileNumber: _userController.rxCustomerDetail.value.mobileNumber,
        );
      }

      fetchDraftOrderNumber();
    } else {
      toastification.show(
        autoCloseDuration: Duration(seconds: 3),
        primaryColor: VardhmanColors.red,
        title: Text(
          'Some error placing the order!',
        ),
      );
    }

    return isSubmitted;
  }

  Future<bool> submitDtmOrder({
    required String merchandiserName,
    required String b2bOrderNumber,
    required List<DraftTableData> dtmEntryLines,
  }) async {
    bool isSubmitted = false;

    isSubmitted = await Api.submitDtmOrder(
      b2bOrderNumber: b2bOrderNumber,
      merchandiserName: merchandiserName,
      branchPlant: _userController.branchPlant,
      soldTo: _userController.rxCustomerDetail.value.soldToNumber,
      shipTo: _userController.shipToNumber,
      company: _userController.rxCustomerDetail.value.companyCode,
      orderTakenBy: _userController.rxUserDetail.value.role,
      dtmEntryLines: dtmEntryLines,
    );

    rxIsProcessing.value = false;

    if (isSubmitted) {
      toastification.show(
          autoCloseDuration: Duration(minutes: 15),
          primaryColor: VardhmanColors.green,
          title: Text('Order $b2bOrderNumber placed successfully!'));

      if (_userController.rxCustomerDetail.value.canSendSMS) {
        Api.sendOrderEntrySMS(
          orderNumber: b2bOrderNumber,
          mobileNumber: _userController.rxCustomerDetail.value.mobileNumber,
        );
      }

      if (_userController.rxCustomerDetail.value.canSendWhatsApp) {
        Api.sendOrderEntryWhatsApp(
          orderNumber: b2bOrderNumber,
          mobileNumber: _userController.rxCustomerDetail.value.mobileNumber,
        );
      }

      fetchDraftOrderNumber();
    } else {
      toastification.show(
        autoCloseDuration: Duration(seconds: 3),
        primaryColor: VardhmanColors.red,
        title: Text('Some error placing the order!'),
      );
    }

    return isSubmitted;
  }

  Future<bool> submitBulkOrder({
    required String merchandiserName,
    required String b2bOrderNumber,
    required List<DraftTableData> bulkEntryLines,
  }) async {
    bool isSubmitted = false;

    isSubmitted = await Api.submitBulkOrder(
      b2bOrderNumber: b2bOrderNumber,
      merchandiserName: merchandiserName,
      branchPlant: _userController.branchPlant,
      soldTo: _userController.rxCustomerDetail.value.soldToNumber,
      shipTo: _userController.shipToNumber,
      company: _userController.rxCustomerDetail.value.companyCode,
      orderTakenBy: _userController.rxUserDetail.value.role,
      bulkEntryLines: bulkEntryLines,
    );

    rxIsProcessing.value = false;

    if (isSubmitted) {
      toastification.show(
        autoCloseDuration: Duration(minutes: 15),
        primaryColor: VardhmanColors.green,
        title: Text('Order $b2bOrderNumber placed successfully!'),
      );

      if (_userController.rxCustomerDetail.value.canSendSMS) {
        Api.sendOrderEntrySMS(
          orderNumber: b2bOrderNumber,
          mobileNumber: _userController.rxCustomerDetail.value.mobileNumber,
        );
      }

      if (_userController.rxCustomerDetail.value.canSendWhatsApp) {
        Api.sendOrderEntryWhatsApp(
          orderNumber: b2bOrderNumber,
          mobileNumber: _userController.rxCustomerDetail.value.mobileNumber,
        );
      }

      fetchDraftOrderNumber();
    } else {
      toastification.show(
        autoCloseDuration: Duration(seconds: 3),
        primaryColor: VardhmanColors.red,
        title: Text('Some error placing the order!'),
      );
    }

    return isSubmitted;
  }

  /// Chosen Ship-To for the review screen: JDE address number, name and
  /// address as returned by ORCH550116 / ORCH550101K.
  String get shipToDisplay {
    final address = _userController.rxDeliveryAddress.value;

    if (address == null) {
      return 'No Ship-To selected';
    }

    final lines = [
      address.addressLine1,
      address.addressLine2,
      address.addressLine3,
      address.addressLine4,
      [address.city, address.state, address.postalCode]
          .where((part) => part.trim().isNotEmpty)
          .join(', '),
      address.country,
    ].map((line) => line.trim()).where((line) => line.isNotEmpty);

    return '${_userController.shipToNumber} - ${address.alphaName.trim()}'
        '${address.deliveryAddressNumber == 0 ? ' (Sold-To)' : ''}\n'
        '${lines.join('\n')}';
  }

  bool get canSubmit =>
      _userController.rxDeliveryAddress.value != null &&
      rxOrderNumber.value != null;
}
