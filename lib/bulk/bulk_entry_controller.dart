import 'dart:developer';
import 'dart:typed_data';
import 'package:drift/drift.dart' as drift;
import 'package:dropdown_search/dropdown_search.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';
import 'package:vardhman_b2b/api/api.dart';
import 'package:vardhman_b2b/api/buyer_info.dart';
import 'package:vardhman_b2b/api/item_catalog_info.dart';
import 'package:vardhman_b2b/bulk/excel_import_dialog.dart';
import 'package:vardhman_b2b/bulk/excel_line.dart';
import 'package:vardhman_b2b/bulk/spreadsheet_reader.dart';
import 'package:vardhman_b2b/catalog/catalog_controller.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/drift/database.dart';
import 'package:vardhman_b2b/orders/order_review_controller.dart';
import 'package:vardhman_b2b/user/user_controller.dart';

class BulkEntryController extends GetxController {
  final OrderReviewController orderReviewController = Get.find();

  final int orderNumber;

  final List<String> _otherLightSouces = [
    'D65',
    'TL84',
    'U35',
    'HORIZON',
    'INCA-A',
    'CWF',
    'UV',
    'U30',
  ];

  final rxPoNumber = ''.obs;

  final rxPoFileName = ''.obs;

  final rxPoFileBytes = Rxn<Uint8List>();

  final List<RxString> inputsInError = <RxString>[].obs;

  final Rxn<DateTime> rxRequestedDate = Rxn<DateTime>(
    DateTime.now().add(
      Duration(days: 15),
    ),
  );

  final rxMerchandisers = <String>[].obs;

  final rxMerchandiser = ''.obs;

  final rxColor = ''.obs;

  final rxShade = ''.obs;

  final rxBuyerInfo = Rxn<BuyerInfo>();

  final rxBuyerName = ''.obs;

  final _rxBuyerCode = ''.obs;

  final rxFirstLightSource = ''.obs;

  final rxSecondLightSource = ''.obs;

  final rxOtherBuyerName = ''.obs;

  final rxSubstrate = ''.obs;

  final rxTicket = ''.obs;

  final rxTex = ''.obs;

  final rxArticle = ''.obs;

  final rxUom = ''.obs;

  final rxUomWithDesc = ''.obs;

  final rxBrand = ''.obs;

  final rxL = ''.obs;

  final rxA = ''.obs;

  final rxB = ''.obs;

  final rxRemark = ''.obs;

  final rxQuantity = ''.obs;

  final rxBulkOrderLines = <DraftTableData>[].obs;

  final catalogController = Get.find<CatalogController>();

  final _rxBuyerInfos = <BuyerInfo>[].obs;

  final rxBillingType = 'Branch'.obs;

  final billingTypes = ['Branch', 'Plant'];

  static const tcRequiredRemark = 'TC Required';

  /// "Direct delivery - TC required", offered for recycled ("R"-prefix)
  /// articles only. A ticked line is direct billed: DraftTable billingType
  /// 'Plant', sent as BillingType 'D' like the F00092 BT/D customers.
  final rxTcRequired = false.obs;

  bool get isRecycledArticle =>
      rxArticle.value.trim().toUpperCase().startsWith('R');

  bool get _isTcLine => rxTcRequired.value && isRecycledArticle;

  String get _lineBillingType => _isTcLine ? 'Plant' : rxBillingType.value;

  String get _lineRemark => [
        if (rxRemark.value.trim().isNotEmpty) rxRemark.value.trim(),
        if (_isTcLine) tcRequiredRemark,
      ].join(' | ');

  static bool isTcRequiredLine(DraftTableData line) =>
      line.billingType == 'Plant';

  final rxRequestType = ''.obs;

  final requestTypes = ['Stitching', 'Embroidery'];

  final rxEndUse = ''.obs;

  final rxShades = <String>[].obs;

  final rxUnitPrice = ''.obs;

  final endUseOptions = [
    "Active/sportswear",
    "Apparel",
    "Apparel Embroidery",
    "Apparel Knitted Outerwear",
    "Apparel Woven Outerwear",
    "Automotive",
    "Bag Making / Closing",
    "Bedding & Quilting",
    "Children/babywear",
    "Denim / jeans",
    "Embroidery - Comp.Multihead",
    "Embroidery - Multi Needles",
    "Embroidery - Non apparel",
    "END Use",
    "EP Fabrics and Knits",
    "Feminine Hygene",
    "Filtration",
    "Footwear",
    "Footwear - Sports",
    "Furniture & Upholstery",
    "Gloves-Indl. Safety",
    "Hand Bags",
    "Home Textiles",
    "Leather Apparel",
    "Leather Footwear",
    "Luggage",
    "Luggage, Handbags",
    "Made Ups",
    "Marine",
    "Miscellaneous- Speciality",
    "Miscellaneous-Apparel",
    "NonFR workwear/uniform",
    "Outdoor Goods",
    "Protective/FR Clothing",
    "Reseller/Distributor",
    "Saddlery",
    "Shoes & Upholestry",
    "Sports Goods",
    "Tea Bags",
    "Tents",
    "Terry Towels",
    "Travel Goods",
    "Tyre Cord",
    "Underwear/Intimates",
    "Wire & Cable",
  ];

  final rxSelectedBulkOrderLines = <DraftTableData>[].obs;

  final Database _database = Get.find();

  final UserController _userController = Get.find(tag: 'userController');

  String get b2bOrderNumber => 'B2BB$orderNumber';

  BulkEntryController({required this.orderNumber}) {
    _database.managers.draftTable
        .filter(
          (f) => f.soldTo.equals(
            _userController.rxUserDetail.value.soldToNumber,
          ),
        )
        .filter(
          (f) => f.orderType.equals('BK'),
        )
        .filter((f) => f.orderNumber.equals(orderNumber))
        .orderBy(
          (o) => o.lineNumber.asc(),
        )
        .watch()
        .listen(
      (draftTableRows) {
        rxBulkOrderLines.assignAll(draftTableRows);
      },
    );

    Api.fetchBuyerInfos().then(
      (buyerInfos) => _rxBuyerInfos.addAll(buyerInfos),
    );

    Api.fetchMerchandiserNames(
            soldToNumber: _userController.rxUserDetail.value.soldToNumber)
        .then(
      (merchandiserNames) => rxMerchandisers.addAll(merchandiserNames),
    );

    rxShade.listen(shadeListener);

    _shipToWorker = ever(
      _userController.rxDeliveryAddress,
      (_) => _repriceForShipTo(),
    );

    rxArticle.listen(articleListener);

    rxBuyerName.listen(buyerNameListener);

    rxOtherBuyerName.listen(otherBuyerListener);

    rxUomWithDesc.listen(uomWithDescListener);

    rxUom.listen(
      (_) {
        // Clearing UOM would otherwise clear the new Article as well.
        if (!_resettingForArticle) {
          selectIfOnlyOneOption(rxUom.hashCode);
        }
      },
    );

    rxPoFileName.listen(poFileNameListener);
  }

  bool _resettingForArticle = false;

  /// Shade kept across an Article change; dropped again if the new article
  /// does not carry it.
  String? _shadeCarriedOver;

  /// A new Article resets its dependent fields (UOM, Ticket, Brand, Tex,
  /// Substrate, unit price), fills them from the catalog when the article
  /// has a single item, and re-runs the Article + Shade UOM lookup (Sno 14)
  /// for the shade already entered.
  void articleListener(String newArticle) {
    if (!isRecycledArticle) {
      rxTcRequired.value = false;
    }

    final shade = rxShade.value;

    _unlockUom();

    _resettingForArticle = true;

    try {
      _shadeToKeep = null;

      rxUomWithDesc.value = '';

      rxUom.value = '';

      rxTicket.value = '';

      rxBrand.value = '';

      rxTex.value = '';

      rxSubstrate.value = '';

      rxUnitPrice.value = '';
    } finally {
      _resettingForArticle = false;
    }

    selectIfOnlyOneOption(rxArticle.hashCode);

    final carryShade = newArticle.trim().isNotEmpty && shade.isNotEmpty;

    _shadeCarriedOver = carryShade ? shade : null;

    // Force the shade listener to run for the carried shade.
    rxShade.value = '';

    resetShade(keepShade: carryShade ? shade : '');
  }

  void poFileNameListener(String newPoFileName) {
    if (newPoFileName.isEmpty) {
      rxPoFileBytes.value = null;
    }
  }

  void uomWithDescListener(String newUomWithDesc) {
    if (newUomWithDesc.isNotEmpty) {
      rxUom.value = newUomWithDesc.split(' - ')[0];
    } else {
      rxUom.value = '';
    }

    final shadeToKeep = _shadeToKeep;

    _shadeToKeep = null;

    resetShade(keepShade: shadeToKeep ?? '');

    if (shadeToKeep != null) {
      shadeListener(shadeToKeep);
    }
  }

  void resetShade({String keepShade = ''}) {
    rxShade.value = keepShade;

    rxShades.clear();

    final article = rxArticle.value.trim();

    // A UOM derived from the shade must not narrow the shade list, or no
    // shade of another UOM could be picked.
    final uom = rxUomLocked.value ? '' : rxUom.value.trim();

    if (article.isNotEmpty) {
      Api.fetchShades(article: article, uom: uom).then(
        (shades) {
          rxShades.assignAll(
            shades
                .where(
                  (shade) => !shade.startsWith('SWT'),
                )
                .toList()
              ..sort(),
          );
        },
      );
    }
  }

  /// Key of the Shade field, used to return the cursor there after a line
  /// is added.
  final shadeDropdownKey = GlobalKey<DropdownSearchState<String>>();

  void focusShade() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => shadeDropdownKey.currentState?.openDropDownSearch(),
    );
  }

  /// Shade typed before UOM; restored after the UOM change resets shades.
  String? _shadeToKeep;

  /// True while the UOM (K2) was derived from Article (K1) + Shade (K3); the
  /// UOM field is read-only meanwhile.
  final rxUomLocked = false.obs;

  /// UOMs that carry the entered shade, when the user must choose one.
  final rxShadeUomChoices = <String>[].obs;

  /// Shade the locked UOM was derived for.
  String? _autoUomShade;

  /// Key of the UOM field, used to open it when the user must choose a UOM.
  final uomDropdownKey = GlobalKey<DropdownSearchState<String>>();

  void _unlockUom() {
    rxUomLocked.value = false;

    rxShadeUomChoices.clear();

    _autoUomShade = null;
  }

  /// Options for the UOM field: the shade's UOMs when several carry it,
  /// otherwise the article's catalog UOMs.
  List<String> get uomChoices => rxShadeUomChoices.isNotEmpty
      ? rxShadeUomChoices.toList()
      : uniqueFilteredUoms;

  /// Sets the UOM (K2) for the entered Article (K1) and Shade (K3) from the
  /// JDE item master (F4101 SEG1/SEG2/SEG3, SRP1 IND/SPE), limited to the
  /// article's UOMs in the item catalog (ORCH55_GetItemCatalogInfo).
  /// One UOM: filled and locked. Several: offered as the only choices.
  /// None: "UOM not found", field stays editable.
  Future<void> _autoSelectUom(String shade) async {
    final article = rxArticle.value.trim();

    final uoms = (await Api.fetchUomsForShade(article: article, shade: shade))
        .where(uniqueFilteredUoms.contains)
        .toList();

    if (rxShade.value != shade ||
        rxArticle.value.trim() != article ||
        (rxUom.value.trim().isNotEmpty && !rxUomLocked.value)) {
      return;
    }

    if (uoms.length == 1) {
      final uom = uoms.first;

      rxShadeUomChoices.clear();

      rxUomLocked.value = true;

      _autoUomShade = shade;

      if (rxUom.value.trim() == uom) {
        shadeListener(shade);
      } else {
        _shadeToKeep = shade;

        rxUomWithDesc.value =
            '$uom - ${orderReviewController.getUomDescription(uom)}';
      }

      return;
    }

    rxUomLocked.value = false;

    _autoUomShade = null;

    if (uoms.isEmpty) {
      rxShadeUomChoices.clear();

      if (shade == _shadeCarriedOver) {
        // Shade kept from the previous article does not exist for this one.
        _shadeCarriedOver = null;

        rxShade.value = '';

        toastification.show(
          autoCloseDuration: Duration(seconds: 4),
          primaryColor: VardhmanColors.red,
          title: Text('Shade $shade is not available for article $article'),
        );

        return;
      }

      toastification.show(
        autoCloseDuration: Duration(seconds: 4),
        primaryColor: VardhmanColors.red,
        title: Text('UOM not found for article $article and shade $shade'),
      );

      return;
    }

    // Keep the shade when the chosen UOM resets the shade list.
    _shadeToKeep = shade;

    rxShadeUomChoices.assignAll(uoms);

    toastification.show(
      autoCloseDuration: Duration(seconds: 4),
      primaryColor: VardhmanColors.orange,
      title: Text(
        'Shade $shade exists in UOMs ${uoms.join(', ')}. Please choose the UOM',
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => uomDropdownKey.currentState?.openDropDownSearch(),
    );
  }

  void shadeListener(String newShade) {
    rxColor.value = '';

    rxUnitPrice.value = '';

    if (_shadeToKeep != null && newShade != _shadeToKeep) {
      _shadeToKeep = null;
    }

    if (newShade != _autoUomShade) {
      rxShadeUomChoices.clear();
    }

    if (_shadeCarriedOver != null && newShade != _shadeCarriedOver) {
      _shadeCarriedOver = null;
    }

    if (newShade.isEmpty) {
      if (!_keepUomLock) {
        _unlockUom();
      }
    } else if (rxUom.value.trim().isEmpty ||
        (rxUomLocked.value && newShade != _autoUomShade)) {
      _autoSelectUom(newShade);

      return;
    }

    if (newShade.isNotEmpty) {
      _fetchUnitPrice(
        getItemNumber(
            article: rxArticle.value, uom: rxUom.value, shade: rxShade.value),
      ).then(
        (unitPrice) => rxUnitPrice.value = unitPrice?.toString() ?? '',
      );
    }
  }

  /// ORCH554074_GetUnitPrice for [itemNumber] at the selected Ship-To.
  Future<double?> _fetchUnitPrice(String itemNumber) => Api.fetchUnitPrice(
        soldToNumber: _userController.rxUserDetail.value.soldToNumber,
        shipToNumber: _userController.shipToNumber,
        itemNumber: itemNumber,
        businessUnit: _userController.branchPlant,
        effectiveDate: DateTime.now(),
      );

  Worker? _shipToWorker;

  /// Re-prices the line being entered and every line already in the order
  /// when the user picks a different Ship-To.
  Future<void> _repriceForShipTo() async {
    final shipTo = _userController.shipToNumber;

    if (rxShade.value.isNotEmpty && rxUom.value.trim().isNotEmpty) {
      rxUnitPrice.value = '';

      _fetchUnitPrice(
        getItemNumber(
            article: rxArticle.value, uom: rxUom.value, shade: rxShade.value),
      ).then(
        (unitPrice) {
          if (shipTo == _userController.shipToNumber) {
            rxUnitPrice.value = unitPrice?.toString() ?? '';
          }
        },
      );
    }

    final lines = rxBulkOrderLines.toList();

    if (lines.isEmpty) {
      return;
    }

    final unpricedLines = <int>[];

    const batchSize = 10;

    for (int i = 0; i < lines.length; i += batchSize) {
      await Future.wait(
        lines.skip(i).take(batchSize).map(
          (line) async {
            final unitPrice = await _fetchUnitPrice(
              getItemNumber(
                  article: line.article, uom: line.uom, shade: line.shade),
            );

            // A newer Ship-To was picked meanwhile; its own re-pricing wins.
            if (shipTo != _userController.shipToNumber) {
              return;
            }

            final hasPrice = unitPrice != null && unitPrice > 0;

            if (!hasPrice) {
              unpricedLines.add(line.lineNumber);
            }

            await _database.managers.draftTable
                .filter((f) => f.orderNumber.equals(orderNumber))
                .filter((f) => f.lineNumber.equals(line.lineNumber))
                .update(
                  (o) => o(
                    unitPrice: drift.Value(hasPrice ? unitPrice : null),
                    lastUpdated: drift.Value(DateTime.now()),
                  ),
                );
          },
        ),
      );
    }

    if (shipTo != _userController.shipToNumber) {
      return;
    }

    unpricedLines.sort();

    toastification.show(
      autoCloseDuration: Duration(seconds: unpricedLines.isEmpty ? 3 : 8),
      primaryColor:
          unpricedLines.isEmpty ? VardhmanColors.green : VardhmanColors.red,
      title: Text(
        unpricedLines.isEmpty
            ? '${lines.length} lines re-priced for Ship-To $shipTo'
            : 'No JDE price for Ship-To $shipTo on line(s) '
                '${unpricedLines.join(', ')}',
      ),
    );
  }

  @override
  void onClose() {
    _shipToWorker?.dispose();

    super.onClose();
  }

  void buyerNameListener(String newBuyerName) {
    final buyerName = newBuyerName.trim();

    rxBuyerInfo.value = null;
    rxOtherBuyerName.value = '';
    _rxBuyerCode.value = '';
    rxFirstLightSource.value = '';
    rxSecondLightSource.value = '';

    if (buyerName.isNotEmpty && buyerName != 'OTHER') {
      final buyerInfo = _rxBuyerInfos.firstWhereOrNull(
        (buyerInfo) => buyerInfo.name == buyerName,
      );

      if (buyerInfo != null) {
        rxBuyerInfo.value = buyerInfo;
        _rxBuyerCode.value = buyerInfo.code;
        rxFirstLightSource.value = buyerInfo.firstLightSource;
        rxSecondLightSource.value = buyerInfo.secondLightSource;
      }
    }
  }

  void otherBuyerListener(String newOtherBuyerName) {
    final otherBuyerName = newOtherBuyerName.trim();

    rxBuyerInfo.value = null;
    _rxBuyerCode.value = '';
    rxFirstLightSource.value = '';
    rxSecondLightSource.value = '';

    if (otherBuyerName.isNotEmpty && buyerNames.contains(otherBuyerName)) {
      final buyerInfo = _rxBuyerInfos.firstWhereOrNull(
        (buyerInfo) => buyerInfo.name == otherBuyerName,
      );

      if (buyerInfo != null) {
        rxBuyerInfo.value = buyerInfo;
        _rxBuyerCode.value = buyerInfo.code;
        rxFirstLightSource.value = buyerInfo.firstLightSource;
        rxSecondLightSource.value = buyerInfo.secondLightSource;
      }
    }
  }

  bool get isLightSource1Enabled {
    if (rxBuyerInfo.value != null) {
      return rxBuyerInfo.value!.firstLightSource.trim().isEmpty;
    } else {
      return rxOtherBuyerName.value.trim().isNotEmpty;
    }
  }

  bool get isLightSource2Enabled {
    if (rxBuyerInfo.value != null) {
      return rxBuyerInfo.value!.secondLightSource.trim().isEmpty;
    } else {
      return rxOtherBuyerName.value.trim().isNotEmpty;
    }
  }

  bool get isSwatchShade =>
      rxShade.value.isNotEmpty && rxShade.value.startsWith('SWT');

  bool get isOtherBuyer => rxBuyerName.value == 'OTHER';

  List<String> get buyerNames =>
      ['OTHER', ..._rxBuyerInfos.map((buyerInfo) => buyerInfo.name)];

  List<String> get firstLightSources =>
      rxBuyerInfo.value?.firstLightSource.trim().isEmpty ?? true
          ? _otherLightSouces
              .where((lightSource) => lightSource != rxSecondLightSource.value)
              .toList()
          : [rxFirstLightSource.value];

  List<String> get secondLightSources =>
      rxBuyerInfo.value?.secondLightSource.trim().isEmpty ?? true
          ? _otherLightSouces
              .where((lightSource) => lightSource != rxFirstLightSource.value)
              .toList()
          : [rxSecondLightSource.value];

  void selectIfOnlyOneOption(int hashCode) {
    if (hashCode == rxArticle.hashCode && rxArticle.value.isEmpty) {
      rxUom.value = '';
      rxUomWithDesc.value = '';
      rxBrand.value = '';
      rxSubstrate.value = '';
      rxTex.value = '';
      rxTicket.value = '';
    } else if (hashCode == rxUom.hashCode && rxUom.value.isEmpty) {
      rxArticle.value = '';
      rxBrand.value = '';
      rxSubstrate.value = '';
      rxTex.value = '';
      rxTicket.value = '';
    } else if (hashCode == rxBrand.hashCode && rxBrand.value.isEmpty) {
      rxArticle.value = '';
      rxUom.value = '';
      rxUomWithDesc.value = '';
      rxSubstrate.value = '';
      rxTex.value = '';
      rxTicket.value = '';
    } else if (hashCode == rxSubstrate.hashCode && rxSubstrate.value.isEmpty) {
      rxArticle.value = '';
      rxUom.value = '';
      rxUomWithDesc.value = '';
      rxBrand.value = '';
      rxTex.value = '';
      rxTicket.value = '';
    } else if (hashCode == rxTex.hashCode && rxTex.value.isEmpty) {
      rxArticle.value = '';
      rxUom.value = '';
      rxUomWithDesc.value = '';
      rxBrand.value = '';
      rxSubstrate.value = '';
      rxTicket.value = '';
    } else if (filteredItems.length == 1) {
      final item = filteredItems.first;

      rxArticle.value = item.article;
      rxUom.value = item.uom;
      rxUomWithDesc.value =
          '${rxUom.value} - ${orderReviewController.getUomDescription(rxUom.value)}';
      rxBrand.value = item.brandDesc;
      rxSubstrate.value = item.substrateDesc;
      rxTex.value = item.tex;
      rxTicket.value = item.ticket;
    }
  }

  List<ItemCatalogInfo> get filteredItems {
    final filteredItems = catalogController.industryItems
        .where(
          (itemCatalogInfo) =>
              (rxArticle.value.isNotEmpty
                  ? itemCatalogInfo.article == (rxArticle.value)
                  : true) &&
              (rxUom.value.isNotEmpty
                  ? itemCatalogInfo.uom == (rxUom.value)
                  : true) &&
              (rxBrand.value.isNotEmpty
                  ? itemCatalogInfo.brandDesc == (rxBrand.value)
                  : true) &&
              (rxSubstrate.value.isNotEmpty
                  ? itemCatalogInfo.substrateDesc == (rxSubstrate.value)
                  : true) &&
              (rxTex.value.isNotEmpty
                  ? itemCatalogInfo.tex == (rxTex.value)
                  : true) &&
              (rxTicket.value.isNotEmpty
                  ? itemCatalogInfo.ticket == (rxTicket.value)
                  : true),
        )
        .toList();

    return filteredItems;
  }

  bool get canAddOrderLine =>
      rxShade.isNotEmpty &&
      (!isSwatchShade || rxColor.isNotEmpty) &&
      buyerOrOtherName.isNotEmpty &&
      rxMerchandiser.isNotEmpty &&
      rxFirstLightSource.value.isNotEmpty &&
      rxArticle.value.isNotEmpty;

  String get _colorRemark => [
        if (rxSecondLightSource.value.trim().isNotEmpty)
          rxSecondLightSource.value,
        if (rxRemark.value.trim().isNotEmpty) rxRemark.value,
        if (_isTcLine) tcRequiredRemark,
        if (rxL.value.trim().isNotEmpty) rxL.value,
        if (rxRequestType.value.isNotEmpty) rxRequestType.value,
        if (rxEndUse.value.isNotEmpty) rxEndUse.value,
      ].join('|');

  int get _lastLineNumber => rxBulkOrderLines.lastOrNull?.lineNumber ?? 0;

  bool validateInputs() {
    inputsInError.clear();

    if (rxUom.value.trim().isEmpty) {
      inputsInError.add(rxUom);
    }

    if (rxMerchandiser.value.trim().isEmpty) {
      inputsInError.add(rxMerchandiser);
    }

    if (rxBuyerName.value.trim().isEmpty) {
      inputsInError.add(rxBuyerName);
    }

    if (isOtherBuyer && rxOtherBuyerName.value.trim().isEmpty) {
      inputsInError.add(rxOtherBuyerName);
    }

    if (rxFirstLightSource.value.trim().isEmpty) {
      inputsInError.add(rxFirstLightSource);
    }

    if (rxArticle.value.trim().isEmpty) {
      inputsInError.add(rxArticle);
    }

    if (rxShade.value.trim().isEmpty) {
      inputsInError.add(rxShade);
    }

    if (rxQuantity.value.trim().isEmpty) {
      inputsInError.add(rxQuantity);
    }

    if (rxPoNumber.value.trim().isEmpty) {
      inputsInError.add(rxPoNumber);
    }

    return inputsInError.isEmpty;
  }

  void addBulkOrderLine() {
    if (!validateInputs()) {
      // toastification.show(
      //   autoCloseDuration: Duration(seconds: 3),
      //   primaryColor: VardhmanColors.red,
      //   title: Text('Please fill all the required fields'),
      // );
    } else if (rxBulkOrderLines.any(
      (bulkOrderLine) =>
          bulkOrderLine.article == rxArticle.value &&
          bulkOrderLine.shade == rxShade.value,
    )) {
      toastification.show(
        autoCloseDuration: Duration(seconds: 3),
        primaryColor: VardhmanColors.red,
        title: Text('Duplicate Article and Shade combination'),
      );
    } else {
      _database.managers.draftTable.create(
        (o) => o(
          article: rxArticle.value,
          billingType: _lineBillingType,
          brand: rxBrand.value,
          buyer: buyerOrOtherName,
          buyerCode: _rxBuyerCode.value,
          colorName: rxColor.value,
          remark: _lineRemark,
          endUse: rxEndUse.value,
          firstLightSource: rxFirstLightSource.value,
          lab: '${rxL.value},${rxA.value},${rxB.value}',
          lineNumber: _lastLineNumber + 1,
          orderNumber: orderNumber,
          orderType: 'BK',
          quantity: int.tryParse(rxQuantity.value) ?? 1,
          requestType: rxRequestType.value,
          secondLightSource: rxSecondLightSource.value,
          shade: rxShade.value,
          soldTo: _userController.rxUserDetail.value.soldToNumber,
          substrate: rxSubstrate.value,
          tex: rxTex.value,
          ticket: rxTicket.value,
          uom: rxUom.value,
          colorRemark: _colorRemark,
          lastUpdated: DateTime.now(),
          merchandiser: rxMerchandiser.value,
          qtxFileName: '',
          requestedDate: drift.Value(rxRequestedDate.value),
          poNumber: rxPoNumber.value,
          poFileName: rxPoFileName.value,
          poFileBytes: drift.Value(rxPoFileBytes.value),
          unitPrice: drift.Value(double.tryParse(rxUnitPrice.value)),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      _clearForNextLine();
    }
  }

  /// Set while Shade is cleared for the next line, so a UOM derived from the
  /// shade (Sno 14) stays locked and is derived again for the next shade.
  bool _keepUomLock = false;

  /// After a line is added only Shade and Quantity are cleared. Article, UOM,
  /// Ticket, Brand, Tex, Substrate and the other fields stay in controller
  /// state until the Article changes; the cursor goes back to Shade.
  void _clearForNextLine() {
    // The shade listener clears Style No. together with the shade.
    final styleNo = rxColor.value;

    _keepUomLock = true;

    try {
      rxShade.value = '';
    } finally {
      _keepUomLock = false;
    }

    rxColor.value = styleNo;

    rxQuantity.value = '';

    focusShade();
  }

  String get buyerOrOtherName =>
      isOtherBuyer ? rxOtherBuyerName.value : rxBuyerName.value;

  void updateBulkOrderLine() {
    final selectedBulkOrderLine = rxSelectedBulkOrderLines.first;

    if (!validateInputs()) {
      // toastification.show(
      //   autoCloseDuration: Duration(seconds: 3),
      //   primaryColor: VardhmanColors.red,
      //   title: Text('Please fill all the required fields'),
      // );
    } else if (rxBulkOrderLines.any(
      (bulkOrderLine) =>
          bulkOrderLine != selectedBulkOrderLine &&
          bulkOrderLine.article == rxArticle.value &&
          bulkOrderLine.shade == rxShade.value,
    )) {
      toastification.show(
        autoCloseDuration: Duration(seconds: 3),
        primaryColor: VardhmanColors.red,
        title: Text('Duplicate Article and Shade combination'),
      );
    } else {
      _database.managers.draftTable
          .filter((f) => f.orderNumber.equals(orderNumber))
          .filter((f) => f.lineNumber.equals(selectedBulkOrderLine.lineNumber))
          .update(
            (o) => o(
              article: drift.Value(rxArticle.value),
              billingType: drift.Value(_lineBillingType),
              brand: drift.Value(rxBrand.value),
              buyer: drift.Value(buyerOrOtherName),
              buyerCode: drift.Value(_rxBuyerCode.value),
              colorName: drift.Value(rxColor.value),
              remark: drift.Value(_lineRemark),
              endUse: drift.Value(rxEndUse.value),
              firstLightSource: drift.Value(rxFirstLightSource.value),
              lineNumber: drift.Value(selectedBulkOrderLine.lineNumber),
              orderNumber: drift.Value(selectedBulkOrderLine.orderNumber),
              orderType: drift.Value(selectedBulkOrderLine.orderType),
              quantity: drift.Value(int.tryParse(rxQuantity.value) ?? 1),
              requestType: drift.Value(rxRequestType.value),
              secondLightSource: drift.Value(rxSecondLightSource.value),
              shade: drift.Value(rxShade.value),
              soldTo:
                  drift.Value(_userController.rxUserDetail.value.soldToNumber),
              substrate: drift.Value(rxSubstrate.value),
              tex: drift.Value(rxTex.value),
              ticket: drift.Value(rxTicket.value),
              uom: drift.Value(rxUom.value),
              colorRemark: drift.Value(_colorRemark),
              lastUpdated: drift.Value(DateTime.now()),
              merchandiser: drift.Value(rxMerchandiser.value),
              requestedDate: drift.Value(rxRequestedDate.value),
              poNumber: drift.Value(rxPoNumber.value),
              poFileName: drift.Value(rxPoFileName.value),
              poFileBytes: drift.Value(rxPoFileBytes.value),
              unitPrice: drift.Value(double.tryParse(rxUnitPrice.value)),
            ),
          );

      rxSelectedBulkOrderLines.clear();

      clearAllInputs(
        skipHashCodes: [
          rxMerchandiser.hashCode,
          rxBuyerName.hashCode,
          if (isOtherBuyer) rxOtherBuyerName.hashCode,
          rxFirstLightSource.hashCode,
          rxSecondLightSource.hashCode,
          rxEndUse.hashCode,
          rxRequestedDate.hashCode,
          rxPoNumber.hashCode,
          rxPoFileName.hashCode,
        ],
      );
    }
  }

  void deleteSelectedLines() {
    for (DraftTableData bulkOrderLine in rxSelectedBulkOrderLines) {
      _database.managers.draftTable
          .filter((f) => f.orderNumber.equals(orderNumber))
          .filter((f) => f.lineNumber.equals(bulkOrderLine.lineNumber))
          .delete();
    }

    rxSelectedBulkOrderLines.clear();
  }

  bool get canClearInputs =>
      rxMerchandiser.value != '' ||
      rxBuyerName.value != '' ||
      rxOtherBuyerName.value != '' ||
      rxFirstLightSource.value != '' ||
      rxSecondLightSource.value != '' ||
      rxArticle.value != '' ||
      rxUomWithDesc.value != '' ||
      rxTicket.value != '' ||
      rxBrand.value != '' ||
      rxTex.value != '' ||
      rxSubstrate.value != '' ||
      rxShade.value != '' ||
      rxColor.value != '' ||
      rxQuantity.value != '' ||
      rxRequestedDate.value != null ||
      rxRemark.value != '' ||
      rxPoNumber.value != '' ||
      rxPoFileName.value != '';

  void clearAllInputs({List<int> skipHashCodes = const []}) {
    rxTcRequired.value = false;

    if (!skipHashCodes.contains(rxMerchandiser.hashCode)) {
      rxMerchandiser.value = '';
    }
    if (!skipHashCodes.contains(rxBuyerName.hashCode)) {
      rxBuyerName.value = '';
    }
    if (!skipHashCodes.contains(rxOtherBuyerName.hashCode)) {
      rxOtherBuyerName.value = '';
    }
    if (!skipHashCodes.contains(rxFirstLightSource.hashCode)) {
      rxFirstLightSource.value = '';
    }
    if (!skipHashCodes.contains(rxSecondLightSource.hashCode)) {
      rxSecondLightSource.value = '';
    }
    if (!skipHashCodes.contains(rxArticle.hashCode)) {
      rxArticle.value = '';
    }
    if (!skipHashCodes.contains(rxUomWithDesc.hashCode)) {
      _unlockUom();

      rxUomWithDesc.value = '';
    }
    if (!skipHashCodes.contains(rxTicket.hashCode)) {
      rxTicket.value = '';
    }
    if (!skipHashCodes.contains(rxBrand.hashCode)) {
      rxBrand.value = '';
    }
    if (!skipHashCodes.contains(rxTex.hashCode)) {
      rxTex.value = '';
    }
    if (!skipHashCodes.contains(rxSubstrate.hashCode)) {
      rxSubstrate.value = '';
    }
    if (!skipHashCodes.contains(rxShade.hashCode)) {
      rxShade.value = '';
    }
    if (!skipHashCodes.contains(rxColor.hashCode)) {
      rxColor.value = '';
    }
    if (!skipHashCodes.contains(rxQuantity.hashCode)) {
      rxQuantity.value = '';
    }
    if (!skipHashCodes.contains(rxRequestedDate.hashCode)) {
      rxRequestedDate.value = null;
    }
    if (!skipHashCodes.contains(rxRemark.hashCode)) {
      rxRemark.value = '';
    }
    if (!skipHashCodes.contains(rxPoNumber.hashCode)) {
      rxPoNumber.value = '';
    }
    if (!skipHashCodes.contains(rxPoFileName.hashCode)) {
      rxPoFileName.value = '';
    }
  }

  List<String> get uniqueFilteredArticles => catalogController.industryItems
      .where(
        (itemCatalogInfo) => (rxUom.value.isNotEmpty
            ? itemCatalogInfo.uom == (rxUom.value)
            : true),
      )
      .map((e) => e.article)
      .toSet()
      .toList();

  List<String> get uniqueFilteredUoms {
    final List<String> uniqueFilteredUoms = catalogController.industryItems
        .where(
          (itemCatalogInfo) => (rxArticle.value.isNotEmpty
              ? itemCatalogInfo.article == (rxArticle.value)
              : true),
        )
        .map((e) => e.uom)
        .toSet()
        .toList();

    log('UOMs - ${uniqueFilteredUoms.toString()}');

    return uniqueFilteredUoms;
  }

  bool _isSubmitting = false;

  /// Order number allocated by the first submit attempt. Reused on retry so a
  /// failed or timed-out submit does not burn a number or create a second
  /// JDE order under a different batch number.
  int? _submitOrderNumber;

  Future<void> submitOrder() async {
    if (_isSubmitting) {
      return;
    }

    _isSubmitting = true;

    try {
      await _submitOrder();
    } finally {
      _isSubmitting = false;
    }
  }

  Future<void> _submitOrder() async {
    final firstPoDocLine = rxBulkOrderLines.firstWhereOrNull(
      (bulkOrderLine) => bulkOrderLine.poFileName.isNotEmpty,
    );
    final submitBulkOrderNumber =
        _submitOrderNumber ??= await Api.fetchBulkOrderNumber();

    if (submitBulkOrderNumber == null) {
      toastification.show(
        autoCloseDuration: Duration(seconds: 3),
        primaryColor: VardhmanColors.red,
        title: Text('Could not get an order number from JDE. Please retry.'),
      );

      return;
    }

    if (firstPoDocLine != null) {
      String emails = await Api.fetchBulkDtmEmailAddresses();
      await Api.uploadMediaAttachment(
        fileBytes: firstPoDocLine.poFileBytes!,
        fileName: firstPoDocLine.poFileName,
        moKey:
            'QTX|QT|||$submitBulkOrderNumber|${_userController.rxUserDetail.value.soldToNumber}|1001|',
        moStructure: 'GT00092',
        version: 'VYTL0016',
        formName: 'P00092_W00092D',
      );

      await Api.supplementalDataEntry(
        databaseCode: 'QTX',
        dataType: 'QT',
        orderNumber: submitBulkOrderNumber,
        lineNumber: 1001,
        b2bOrderNumber: 'B2BB$submitBulkOrderNumber',
        soldToNumber: _userController.rxUserDetail.value.soldToNumber,
        userName: _userController.rxUserDetail.value.name,
      );

      await Api.supplementalDataWrapper(
        databaseCode: 'QTX',
        dataType: 'QT',
        orderNumber: submitBulkOrderNumber,
        lineNumber: 1001,
        soldTo: _userController.rxUserDetail.value.soldToNumber,
        emailAddresses: emails,
        fileType: 'PO Document',
      );
    }

    final isSubmitted = await orderReviewController.submitBulkOrder(
      b2bOrderNumber: 'B2BB$submitBulkOrderNumber',
      merchandiserName: rxMerchandiser.value,
      bulkEntryLines: rxBulkOrderLines,
    );

    if (isSubmitted) {
      _submitOrderNumber = null;

      _database.managers.draftTable
          .filter((f) => f.orderNumber.equals(orderNumber))
          .delete();

      Get.back();
    }
  }

  bool get canSubmit =>
      rxMerchandiser.value.isNotEmpty && rxBulkOrderLines.isNotEmpty;

  void selectBulkOrderLine(DraftTableData bulkOrderLine) {
    if (rxSelectedBulkOrderLines.contains(bulkOrderLine)) {
      rxSelectedBulkOrderLines.remove(bulkOrderLine);
    } else {
      rxSelectedBulkOrderLines.add(bulkOrderLine);
    }

    if (rxSelectedBulkOrderLines.isNotEmpty) {
      clearAllInputs();

      _populateInputs(bulkOrderLine: rxSelectedBulkOrderLines.last);
    }
  }

  Future<void> importExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: supportedSpreadsheetExtensions,
        withData: true,
      );

      if (result == null) {
        // User canceled the picker
        log('No file selected');

        return;
      }

      final pickedFile = result.files.single;

      final List<List<String>> sheetRows;

      try {
        sheetRows = readSpreadsheetRows(
          bytes: pickedFile.bytes!,
          fileName: pickedFile.name,
        );
      } catch (e) {
        log('importExcel read error - $e');

        toastification.show(
          autoCloseDuration: Duration(seconds: 5),
          primaryColor: VardhmanColors.red,
          title: Text(
            e is FormatException
                ? e.message
                : 'Could not read ${pickedFile.name}. Please upload a valid .xlsx, .xls or .csv file.',
          ),
        );

        return;
      }

      final importRows = <ExcelImportRow>[];

      // Row 0 is the header.
      for (int i = 1; i < sheetRows.length; i++) {
        final excelLine = ExcelLine.fromCells(sheetRows[i]);

        if (!excelLine.isBlank) {
          importRows.add(ExcelImportRow(rowNumber: i + 1, line: excelLine));
        }
      }

      if (importRows.isEmpty) {
        toastification.show(
          autoCloseDuration: Duration(seconds: 3),
          primaryColor: VardhmanColors.red,
          title: Text('No order lines found in ${pickedFile.name}'),
        );

        return;
      }

      await _validateImportRows(importRows);

      if (importRows.any((row) => !row.isValid)) {
        final proceed = await Get.dialog<bool>(
          ExcelImportDialog(
            rows: importRows,
            onRevalidate: () => _validateImportRows(importRows),
          ),
          barrierDismissible: false,
        );

        if (proceed != true) {
          return;
        }
      }

      final validRows = importRows.where((row) => row.isValid).toList();

      await _insertImportRows(validRows);

      toastification.show(
        autoCloseDuration: Duration(seconds: 3),
        primaryColor: VardhmanColors.green,
        title:
            Text('${validRows.length} of ${importRows.length} lines uploaded'),
      );
    } catch (e) {
      log('Error: $e');
    }
  }

  /// Validates every row not already known to be valid: required fields,
  /// duplicates, item present in JDE item master (F4101) and priced in JDE
  /// (ORCH554074_GetUnitPrice).
  Future<void> _validateImportRows(List<ExcelImportRow> importRows) async {
    final rowsToCheck = <ExcelImportRow>[];

    for (final row in importRows) {
      if (row.isValid && row.unitPrice != null) {
        continue;
      }

      row.error = null;
      row.unitPrice = null;

      final missingFields = row.line.missingFields;

      if (missingFields.isNotEmpty) {
        row.error = 'Missing ${missingFields.join(', ')}';
      } else if (importRows.any(
            (other) =>
                other != row &&
                other.line.itemNumber == row.line.itemNumber &&
                // An earlier line, or a line already accepted (e.g. when a
                // fixed line now matches a later valid one).
                ((other.rowNumber < row.rowNumber &&
                        other.line.missingFields.isEmpty) ||
                    other.unitPrice != null),
          ) ||
          rxBulkOrderLines.any(
            (orderLine) =>
                orderLine.article == row.line.article &&
                orderLine.uom == row.line.uom &&
                orderLine.shade == row.line.shade,
          )) {
        row.error = 'Duplicate item number';
      } else {
        rowsToCheck.add(row);
      }
    }

    if (rowsToCheck.isEmpty) {
      return;
    }

    final validItemNumbers = await Api.validateItemNumbers(
      rowsToCheck.map((row) => row.line.itemNumber).toSet().toList(),
    );

    final rowsToPrice = <ExcelImportRow>[];

    for (final row in rowsToCheck) {
      if (validItemNumbers.contains(row.line.itemNumber)) {
        rowsToPrice.add(row);
      } else {
        row.error = 'Item not found in JDE item master or obsolete';
      }
    }

    const batchSize = 10;

    for (int i = 0; i < rowsToPrice.length; i += batchSize) {
      await Future.wait(
        rowsToPrice.skip(i).take(batchSize).map(
          (row) async {
            final unitPrice = await _fetchUnitPrice(row.line.itemNumber);

            if (unitPrice == null || unitPrice <= 0) {
              row.error = 'Price not available in JDE';
            } else {
              row.unitPrice = unitPrice;
            }
          },
        ),
      );
    }
  }

  Future<void> _insertImportRows(List<ExcelImportRow> importRows) async {
    var lineNumber = _lastLineNumber;

    for (final importRow in importRows) {
      final excelLine = importRow.line;

      lineNumber++;

      final catalogItem = catalogController.industryItem(
        article: excelLine.article,
        uom: excelLine.uom,
      );

      final buyerInfo = _rxBuyerInfos.firstWhereOrNull(
        (buyerInfo) =>
            buyerInfo.name.toLowerCase() == excelLine.buyer.toLowerCase(),
      );

      String lightSource1, lightSource2;

      if (buyerInfo != null) {
        lightSource1 = buyerInfo.firstLightSource;

        lightSource2 = buyerInfo.secondLightSource;
      } else {
        final excelLightSourceParts = excelLine.lightSources.split(',');

        lightSource1 = excelLightSourceParts[0];

        lightSource2 =
            excelLightSourceParts.length > 1 ? excelLightSourceParts[1] : '';
      }

      await _database.managers.draftTable.create(
        (o) => o(
          poNumber: excelLine.poNumber,
          merchandiser: excelLine.merchandiser,
          buyer: excelLine.buyer,
          firstLightSource: lightSource1,
          secondLightSource: lightSource2,
          article: excelLine.article,
          uom: excelLine.uom,
          shade: excelLine.shade,
          colorName: excelLine.styleNo,
          quantity: excelLine.quantity,
          buyerCode: buyerInfo?.code ?? '',
          brand: catalogItem?.brandDesc ?? '',
          substrate: catalogItem?.substrateDesc ?? '',
          ticket: catalogItem?.ticket ?? '',
          tex: catalogItem?.tex ?? '',
          unitPrice: drift.Value(importRow.unitPrice),
          billingType: '',
          remark: '',
          endUse: '',
          lab: '',
          lineNumber: lineNumber,
          orderNumber: orderNumber,
          orderType: 'BK',
          requestType: '',
          soldTo: _userController.rxUserDetail.value.soldToNumber,
          colorRemark: '',
          lastUpdated: DateTime.now(),
          qtxFileName: '',
          requestedDate: drift.Value(rxRequestedDate.value),
          poFileName: '',
          poFileBytes: drift.Value(null),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );
    }
  }

  void _populateInputs({required DraftTableData bulkOrderLine}) {
    final isOtherBuyer = !buyerNames.contains(bulkOrderLine.buyer);
    rxMerchandiser.value = bulkOrderLine.merchandiser;
    rxBuyerName.value = isOtherBuyer ? 'OTHER' : bulkOrderLine.buyer;
    rxOtherBuyerName.value = isOtherBuyer ? bulkOrderLine.buyer : '';
    _rxBuyerCode.value = bulkOrderLine.buyerCode;
    rxFirstLightSource.value = bulkOrderLine.firstLightSource;
    rxSecondLightSource.value = bulkOrderLine.secondLightSource;
    rxArticle.value = bulkOrderLine.article;
    rxUomWithDesc.value =
        '${bulkOrderLine.uom} - ${orderReviewController.getUomDescription(bulkOrderLine.uom)}';
    rxShade.value = bulkOrderLine.shade;
    rxColor.value = bulkOrderLine.colorName;
    rxQuantity.value = bulkOrderLine.quantity.toString();
    rxRequestedDate.value = bulkOrderLine.requestedDate;
    rxPoFileName.value = bulkOrderLine.poFileName;
    rxPoNumber.value = bulkOrderLine.poNumber;
    rxPoFileBytes.value = bulkOrderLine.poFileBytes;
    rxUnitPrice.value = bulkOrderLine.unitPrice?.toString() ?? '';
    rxTcRequired.value = isTcRequiredLine(bulkOrderLine);
    rxRemark.value = bulkOrderLine.remark
        .split(' | ')
        .where((part) => part != tcRequiredRemark)
        .join(' | ');
  }

  bool get merchandiserHasError => inputsInError.contains(rxMerchandiser);

  bool get buyerNameHasError => inputsInError.contains(rxBuyerName);

  bool get otherBuyerNameHasError => inputsInError.contains(rxOtherBuyerName);

  bool get firstLightSourceHasError =>
      inputsInError.contains(rxFirstLightSource);

  bool get articleHasError => inputsInError.contains(rxArticle);

  bool get shadeHasError => inputsInError.contains(rxShade);

  bool get colorHasError => inputsInError.contains(rxColor);

  bool get uomHasError => inputsInError.contains(rxUom);

  bool get quantityHasError => inputsInError.contains(rxQuantity);

  bool get poNumberHasError => inputsInError.contains(rxPoNumber);

  List<DraftTableData> get bulkOrderLinesDescending => rxBulkOrderLines.toList()
    ..sort(
      (a, b) => b.lineNumber.compareTo(a.lineNumber),
    );
}
