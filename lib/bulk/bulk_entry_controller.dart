import 'dart:developer';
import 'dart:typed_data';
import 'package:drift/drift.dart' as drift;
import 'package:dropdown_search/dropdown_search.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';
import 'package:vardhman_b2b/common/order_quantity_log.dart';
import 'package:vardhman_b2b/api/api.dart';
import 'package:vardhman_b2b/common/shade_uom_lookup.dart';
import 'package:vardhman_b2b/api/buyer_info.dart';
import 'package:vardhman_b2b/api/item_catalog_info.dart';
import 'package:vardhman_b2b/bulk/excel_import_dialog.dart';
import 'package:vardhman_b2b/bulk/excel_line.dart';
import 'package:vardhman_b2b/bulk/spreadsheet_reader.dart';
import 'package:vardhman_b2b/catalog/catalog_controller.dart';
import 'package:vardhman_b2b/constants.dart';
import 'package:vardhman_b2b/drift/database.dart';
import 'package:vardhman_b2b/orders/direct_delivery_tc.dart';
import 'package:vardhman_b2b/segment/segment_controller.dart';
import 'package:vardhman_b2b/orders/order_review_controller.dart';
import 'package:vardhman_b2b/user/user_controller.dart';

class BulkEntryController extends GetxController with DirectDeliveryTc {
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

  @override
  final rxArticle = ''.obs;

  final rxUom = ''.obs;

  final rxUomWithDesc = ''.obs;

  final rxBrand = ''.obs;

  final rxL = ''.obs;

  final rxA = ''.obs;

  final rxB = ''.obs;

  @override
  final rxRemark = ''.obs;

  final rxQuantity = ''.obs;

  final rxBulkOrderLines = <DraftTableData>[].obs;

  final catalogController = Get.find<CatalogController>();

  final _segmentController = Get.find<SegmentController>();

  final _rxBuyerInfos = <BuyerInfo>[].obs;

  @override
  final rxBillingType = 'Branch'.obs;

  final billingTypes = ['Branch', 'Plant'];

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

    rxMerchandiser.value = _userController.lastMerchandiser;

    rxMerchandiser.listen((merchandiser) {
      if (merchandiser.isNotEmpty) {
        _userController.lastMerchandiser = merchandiser;
      }
    });

    rxShade.listen(shadeListener);


    initDirectDeliveryTc();

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
        if (!_resettingForArticle && !_clearingForShade) {
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

  /// Shade of the selected line when it was imported without a UOM; kept
  /// when a UOM is picked until the user changes the shade.
  String? _lineShadeToKeep;

  /// A new Article resets its dependent fields (UOM, Ticket, Brand, Tex,
  /// Substrate, unit price), fills them from the catalog when the article
  /// has a single item, and re-runs the Article + Shade UOM lookup (Sno 14)
  /// for the shade already entered.
  void articleListener(String newArticle) {
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

    // The shade of a selected line imported without a UOM is kept too, as
    // long as the user has not changed it.
    final lineShade = _lineShadeToKeep;

    final shadeToKeep = _shadeToKeep ??
        (lineShade != null && rxShade.value == lineShade ? lineShade : null);

    _shadeToKeep = null;

    resetShade(keepShade: shadeToKeep ?? '');

    if (shadeToKeep != null) {
      shadeListener(shadeToKeep);
    }
  }

  /// Whether the Shade is one of the chosen article's shades (the list the
  /// Shade field offers); typed text that matches none is not a shade.
  bool get isShadeOfArticle => rxShades.contains(rxShade.value.trim());

  /// Only a shade from the article's list is taken (no free text).
  void _showShadeNotOfArticle() {
    toastification.show(
      autoCloseDuration: Duration(seconds: 4),
      primaryColor: VardhmanColors.red,
      title: Text(
        'Shade ${rxShade.value.trim()} is not available for article '
        '${rxArticle.value.trim()}. Pick one from the list.',
      ),
    );
  }

  void resetShade({String keepShade = ''}) {
    rxShade.value = keepShade;

    rxShades.clear();

    final article = rxArticle.value.trim();

    // A UOM derived from the shade must not narrow the shade list, or no
    // shade of another UOM could be picked.
    final uom = rxUomLocked.value ? '' : rxUom.value.trim();

    if (article.isNotEmpty) {
      _shadeUomsFor(article).then(
        (shadeUoms) {
          if (rxArticle.value.trim() != article) {
            return;
          }

          rxShades.assignAll(
            shadeUoms.entries
                .where((entry) => uom.isEmpty || entry.value.contains(uom))
                .map((entry) => entry.key)
                .where(
                  (shade) => !shade.startsWith('SWT'),
                )
                .toList()
              ..sort(),
          );

          if (_openShadeWhenLoaded) {
            _openShadeWhenLoaded = false;

            focusShade();
          }
        },
      );
    }
  }

  final _shadeUomLookup = ShadeUomLookup();

  Future<Map<String, List<String>>> _shadeUomsFor(String article) =>
      _shadeUomLookup.forArticle(article, catalogController.orderItems);

  /// Key of the Shade field, used to open it after an Article is picked.
  final shadeDropdownKey = GlobalKey<DropdownSearchState<String>>();

  void focusShade() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => shadeDropdownKey.currentState?.openDropDownSearch(),
    );
  }

  /// Set when the user picks an Article; Shade opens once the article's
  /// shades are loaded.
  bool _openShadeWhenLoaded = false;

  /// Article picked by the user: the cursor moves on to Shade.
  void onArticlePicked(String article) {
    _openShadeWhenLoaded = article.trim().isNotEmpty && rxShade.value.isEmpty;
  }

  /// Set while [onShadePicked] clears the UOM, so the UOM listener does not
  /// clear the Article with it.
  bool _clearingForShade = false;

  /// Shade cleared by the user: the UOM derived from it and the Ticket that
  /// follows the UOM go blank too. Article stays.
  void onShadePicked(String shade) {
    if (shade.isNotEmpty) {
      return;
    }

    _unlockUom();

    _clearingForShade = true;

    try {
      rxUomWithDesc.value = '';

      rxUom.value = '';

      rxTicket.value = '';
    } finally {
      _clearingForShade = false;
    }
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

  /// Sets the UOM (K2) for the entered Article (K1) and Shade (K3): the
  /// article's UOMs in the item catalog (ORCH55_GetItemCatalogInfo) that carry
  /// the shade in the JDE item master (F4101 SEG1/SEG2/SEG3, SRP1 IND/SPE).
  /// One UOM: filled and locked. Several: offered as the only choices.
  /// None: "UOM not found", field stays editable.
  Future<void> _autoSelectUom(String shade) async {
    final article = rxArticle.value.trim();

    final shadeUoms = await _shadeUomsFor(article);

    var uoms = shadeUoms[shade] ?? <String>[];

    if (uoms.isEmpty) {
      // Shade typed, or its UOMs unknown (Article-only fallback): ask JDE
      // for this shade directly before reporting "UOM not found".
      uoms = (await Api.fetchUomsForShade(article: article, shade: shade))
          .where(uniqueFilteredUoms.contains)
          .toList();
    }

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

    // The user changed (or cleared) the imported line's shade.
    if (_lineShadeToKeep != null && newShade != _lineShadeToKeep) {
      _lineShadeToKeep = null;
    }

    if (newShade.isEmpty) {
      _unlockUom();
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
  Future<double?> _fetchUnitPrice(String itemNumber, {String? logLabel}) =>
      Api.fetchUnitPrice(
        soldToNumber: _userController.rxUserDetail.value.soldToNumber,
        shipToNumber: _userController.shipToNumber,
        itemNumber: itemNumber,
        businessUnit: _userController.branchPlant,
        effectiveDate: DateTime.now(),
        logLabel: logLabel,
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
      // UOM is not filled here: it follows from the shade (Sno 14).
      rxBrand.value = item.brandDesc;
      rxSubstrate.value = item.substrateDesc;
      rxTex.value = item.tex;
      rxTicket.value = item.ticket;
    }
  }

  List<ItemCatalogInfo> get filteredItems {
    final filteredItems = catalogController.orderItems
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
        // The remark typed, with "TC Required" for a TC line.
        if (lineRemark.isNotEmpty) lineRemark,
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
    } else if (!allowsArticle(rxArticle.value)) {
      toastification.show(
        autoCloseDuration: Duration(seconds: 4),
        primaryColor: VardhmanColors.red,
        title: Text(DirectDeliveryTc.onlyRArticlesMessage),
      );
    } else if (!isShadeOfArticle) {
      _showShadeNotOfArticle();
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
          billingType: lineBillingType,
          brand: rxBrand.value,
          buyer: buyerOrOtherName,
          buyerCode: _rxBuyerCode.value,
          colorName: rxColor.value,
          remark: lineRemark,
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
    } else if (!allowsArticle(rxArticle.value)) {
      toastification.show(
        autoCloseDuration: Duration(seconds: 4),
        primaryColor: VardhmanColors.red,
        title: Text(DirectDeliveryTc.onlyRArticlesMessage),
      );
    } else if (!isShadeOfArticle) {
      _showShadeNotOfArticle();
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
              billingType: drift.Value(lineBillingType),
              brand: drift.Value(rxBrand.value),
              buyer: drift.Value(buyerOrOtherName),
              buyerCode: drift.Value(_rxBuyerCode.value),
              colorName: drift.Value(rxColor.value),
              remark: drift.Value(lineRemark),
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

      // Back to adding.
      rxSelectedBulkOrderLines.clear();

      _clearForNextLine();
    }
  }

  /// After a line is added or updated the user picks a shade again for the
  /// same article: Shade, UOM, Ticket, Color Name, unit price and Quantity
  /// go blank and the shade list is reloaded for the article. The Article
  /// and what it maps to (Brand, Tex, Substrate) stay, as do the order-level
  /// fields (Merchandiser, Buyer, PO, Expected Delivery Date...).
  void _clearForNextLine() {
    rxShade.value = '';

    // As when the user clears the shade: UOM and Ticket go blank without
    // the UOM listener clearing the Article; the shade list is reloaded
    // for the article (uomWithDescListener).
    onShadePicked('');

    rxColor.value = '';

    rxUnitPrice.value = '';

    rxQuantity.value = '';

    debugPrint('[ORDERS] Bulk line saved: Shade, UOM, Ticket, Color and '
        'Quantity cleared for the next line of ${rxArticle.value}');
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

  @override
  List<DraftTableData> get tcOrderLines => rxBulkOrderLines;

  @override
  List<DraftTableData> get tcSelectedLines => rxSelectedBulkOrderLines;

  /// Articles for the Article field; "R" articles only in a TC order.
  /// Rx values read once, not once per catalog item (thousands), and the
  /// TC rule applied once per article: the list is rebuilt with the form.
  List<String> get uniqueFilteredArticles {
    final uom = rxUom.value;

    return allowedArticles(
      catalogController.orderItems
          .where((itemCatalogInfo) => uom.isEmpty || itemCatalogInfo.uom == uom)
          .map((itemCatalogInfo) => itemCatalogInfo.article),
    );
  }

  List<String> get uniqueFilteredUoms {
    final List<String> uniqueFilteredUoms = catalogController.orderItems
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
    // Nothing is sent (not even an order number taken) while a line has
    // a quantity of 0.
    if (!checkOrderLineQuantities(orderType: 'Bulk', lines: rxBulkOrderLines)) {
      return;
    }

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

  /// Deletes the lines of this order put in by an earlier Excel import
  /// (marked with their file name in qtxFileName, which Bulk lines do not
  /// use otherwise). Lines added from the form stay.
  Future<void> _deleteImportedLines() async {
    final deleted = await _database.managers.draftTable
        .filter((f) => f.orderNumber.equals(orderNumber))
        .filter((f) => f.qtxFileName.equals('').not())
        .delete();

    debugPrint('[BULK IMPORT] $deleted line(s) of the earlier import cleared');
  }

  /// Whether [_showImportLoader]'s spinner is up.
  bool _isImportLoaderShown = false;

  /// A small spinner over the page, no text, while a file is read and
  /// checked and while the lines are saved: nothing can be clicked until
  /// [_hideImportLoader].
  Future<void> _showImportLoader() async {
    if (_isImportLoaderShown) {
      return;
    }

    _isImportLoaderShown = true;

    Get.dialog<void>(
      const PopScope(
        canPop: false,
        child: Center(
          child: SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      ),
      barrierDismissible: false,
      barrierColor: Colors.black26,
    );

    // Drawn before the work that follows (the sheet is read on the main
    // thread).
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  void _hideImportLoader() {
    if (!_isImportLoaderShown) {
      return;
    }

    _isImportLoaderShown = false;

    Get.back<void>();
  }

  Future<void> importExcel() async {
    // As Clear Inputs: a new import starts from an empty form. The
    // Expected Delivery Date stays: the imported lines are given it.
    clearAllInputs(skipHashCodes: [rxRequestedDate.hashCode]);

    rxSelectedBulkOrderLines.clear();

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

      await _showImportLoader();

      // The lines of the earlier import are replaced by this one.
      await _deleteImportedLines();

      final List<List<String>> sheetRows;

      try {
        sheetRows = readSpreadsheetRows(
          bytes: pickedFile.bytes!,
          fileName: pickedFile.name,
        );
      } catch (e) {
        log('importExcel read error - $e');

        _hideImportLoader();

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

      final importRows = importRowsFromSheet(sheetRows);

      debugPrint(
        '[BULK IMPORT] ${pickedFile.name}: ${sheetRows.length} sheet rows, '
        '${importRows.length} lines (empty and repeated header rows skipped)',
      );

      if (importRows.isEmpty) {
        _hideImportLoader();

        toastification.show(
          autoCloseDuration: Duration(seconds: 3),
          primaryColor: VardhmanColors.red,
          title: Text('No order lines found in ${pickedFile.name}'),
        );

        return;
      }

      await _validateImportRows(importRows);

      // TC Required, one box for all lines, offered only when every
      // uploaded line is an "R" article (a TC order needs "R" articles
      // anyway: the others are red). In a TC order it starts ticked.
      final tcOffered = isTcLocked || offersTcRequired(importRows);

      for (final row in importRows) {
        row.tcRequired = isTcLocked;
      }

      _hideImportLoader();

      // Shown every time: valid lines in green, others in red, and any line
      // can be fixed or deleted before the upload.
      final proceed = await Get.dialog<bool>(
        ExcelImportDialog(
          rows: importRows,
          offersTc: tcOffered,
          onRevalidate: () => _validateImportRows(importRows),
        ),
        barrierDismissible: false,
      );

      if (proceed != true) {
        return;
      }

      final validRows = importRows.where((row) => row.canUpload).toList();

      await _showImportLoader();

      await _insertImportRows(
        validRows,
        tcOffered: tcOffered,
        fileName: pickedFile.name,
      );

      _hideImportLoader();

      toastification.show(
        autoCloseDuration: Duration(seconds: 3),
        primaryColor: VardhmanColors.green,
        title:
            Text('${validRows.length} of ${importRows.length} lines uploaded'),
      );
    } catch (e) {
      log('Error: $e');
    } finally {
      // Never left up, also after an error.
      _hideImportLoader();
    }
  }

  /// Validates every row not already found valid.
  ///
  /// Red (not uploaded): no Article or Shade; the Article or the Shade, each
  /// checked on its own, not in the JDE item master (F4101; these rows get a
  /// Delete button in the grid); an article the TC rule or the segment does
  /// not allow (as in the form); or several UOMs for the Article / Shade
  /// (one has to be entered in Fix).
  ///
  /// Yellow: no Quantity or one under 1 (fixed in the Fix modal; not
  /// uploaded until then), or, uploaded as is, the Article and the Shade in
  /// JDE but not together, or no UOM found for them.
  ///
  /// The UOM comes from the sheet's uom column when it has one, otherwise
  /// it is looked up from the Article and Shade as the form does
  /// (Api.fetchUomsForShade). The JDE unit price is filled in when JDE has
  /// one; without one the line is uploaded without a price, as from the
  /// form.
  Future<void> _validateImportRows(List<ExcelImportRow> importRows) async {
    final rowsToCheck = <ExcelImportRow>[];

    for (final row in importRows) {
      if (row.isChecked) {
        continue;
      }

      row.error = null;
      row.isNotFoundInJde = false;
      row.warning = null;
      row.unitPrice = null;

      // A UOM found earlier is looked up again: the Article or Shade may
      // have been fixed since.
      if (row.uomLookedUp) {
        row
          ..line = row.line.copyWith(uom: '')
          ..uomLookedUp = false;
      }

      final line = row.line;

      final missingRequiredFields = line.missingRequiredFields;

      debugPrint(
        '[BULK IMPORT] Row ${row.rowNumber} required fields: '
        'Article "${line.article}", Shade "${line.shade}", '
        'Quantity "${line.quantityText}" '
        '(must be at least 1: ${line.quantity >= 1 ? 'OK' : 'NOT OK'}) '
        '→ ${missingRequiredFields.isEmpty ? 'OK' : 'missing ${missingRequiredFields.join(', ')}'}',
      );

      // The Quantity (ExcelLine.quantityProblem: yellow, fixed in the Fix
      // modal, the line not uploaded until then) is checked with the
      // Article and Shade, never instead of them: all the line's problems
      // are shown together, the Article / Shade first
      // (ExcelImportRow.problems).
      final missingArticleOrShade = [
        for (final field in missingRequiredFields)
          if (field != 'Quantity') field,
      ];

      if (missingArticleOrShade.isNotEmpty) {
        row.error = 'Missing ${missingArticleOrShade.join(', ')}';
      } else if (!allowsArticle(line.article)) {
        // A TC Required order takes "R" articles only.
        row.error = 'TC Required order: only articles with an "R"';
      } else if (_segmentErrorOf(line.article) case final segmentError?) {
        row.error = segmentError;
      } else {
        rowsToCheck.add(row);
      }
    }

    debugPrint(
      '[BULK IMPORT] Validating ${importRows.length} rows, '
      '${rowsToCheck.length} need JDE checks',
    );

    if (rowsToCheck.isNotEmpty) {
      await _checkImportRowsInJde(rowsToCheck);
    }

    for (final row in importRows) {
      row.isChecked = row.canUpload;

      final problems = row.problems;

      // One line per row, so a row can be matched to the JDE calls above
      // (debugPrint, so release builds log too). Problems most important
      // first: Article / Shade, then Quantity.
      debugPrint(
        '[BULK IMPORT] Row ${row.rowNumber} ${row.line.itemNumber}: '
        '${problems.isEmpty ? 'OK' : '${row.isValid ? 'WARNING' : 'ERROR'}: ${problems.join('; ')}'}'
        '${row.isValid ? ', unit price ${row.unitPrice}' : ''}',
      );
    }

    final invalidCount = importRows.where((row) => !row.canUpload).length;

    final warningCount = importRows.where((row) => row.hasWarning).length;

    debugPrint(
      '[BULK IMPORT] ${importRows.length - invalidCount} to upload, '
      '$warningCount with warnings, $invalidCount to fix (errors or '
      'quantity)',
    );
  }

  /// Error for an Excel [article] the catalog has under a category outside
  /// the selected segment, or null. Articles the catalog does not have are
  /// left to the JDE item master check.
  String? _segmentErrorOf(String article) {
    final category = catalogController.categoryOfArticle(article);

    final segment = _segmentController.segment;

    if (category == null ||
        segment == null ||
        segment.includesCategory(category)) {
      return null;
    }

    logSegment('Excel upload: article $article is $category, not in '
        '${segment.title} (${segment.categories.join(', ')}); row rejected');

    return 'Article is $category, not in the selected segment '
        '(${segment.code})';
  }

  /// JDE calls at the same time while checking an import: a new one starts
  /// as soon as one ends.
  static const _importConcurrency = 8;

  /// Runs [task] on each of [items], [_importConcurrency] at a time; a new
  /// one starts as soon as one ends, never waiting for a whole batch.
  static Future<void> _forEachConcurrently<T>(
    Iterable<T> items,
    Future<void> Function(T item) task,
  ) async {
    final queue = items.toList();

    var next = 0;

    Future<void> worker() async {
      while (next < queue.length) {
        await task(queue[next++]);
      }
    }

    await Future.wait([
      for (var i = 0; i < _importConcurrency && i < queue.length; i++)
        worker(),
    ]);
  }

  /// JDE checks for [rowsToCheck]: the Article / Shade combination in the
  /// item master (F4101, any UOM, obsolete or not; a warning when not
  /// found), the UOM for rows without one, and the unit price. Each call is
  /// logged in full with a `[BULK IMPORT]` tag.
  ///
  /// As few calls as possible, at the same time where they do not depend
  /// on each other: the pairs and the UOMs of all rows in two F4101 queries
  /// run together; then the Article / Shade checks on their own (only for
  /// pairs not found) and the unit prices (once per item) together.
  Future<void> _checkImportRowsInJde(List<ExcelImportRow> rowsToCheck) async {
    final stopwatch = Stopwatch()..start();

    String key(String value) => value.trim().toUpperCase();

    final articles =
        rowsToCheck.map((row) => row.line.article).toSet().toList();

    final shades = rowsToCheck.map((row) => row.line.shade).toSet().toList();

    // How the Article / Shade is checked. The call's full payload and
    // response follow, under the same label (see Api._logOrderRequest).
    debugPrint(
      '[BULK IMPORT] Article / Shade check: POST /v2/dataservice (BROWSE) '
      'on the JDE item master, table F4101, for Article (F4101.SEG1) in '
      '${articles.length} article(s) and Shade (F4101.SEG3) in '
      '${shades.length} shade(s), no other filter (any UOM, obsolete or '
      'not). Not found is a warning, not an error.\n'
      'ARTICLES: ${articles.join(', ')}\n'
      'SHADES: ${shades.join(', ')}',
    );

    final rowsWithoutUom =
        rowsToCheck.where((row) => row.line.uom.isEmpty).toList();

    // Both F4101 queries at once: they do not depend on each other.
    final pairsCall = Api.fetchArticleShadePairs(
      articles: articles,
      shades: shades,
      logLabel: '[BULK IMPORT] Article / Shade check (F4101)',
    );

    final uomsCall = rowsWithoutUom.isEmpty
        ? Future.value(<(String, String), List<String>>{})
        : Api.fetchUomsForPairs(
            articles:
                rowsWithoutUom.map((row) => row.line.article).toSet().toList(),
            shades:
                rowsWithoutUom.map((row) => row.line.shade).toSet().toList(),
            logLabel: '[BULK IMPORT] UOM lookup (F4101 SEG2), all rows',
          );

    final pairs = await pairsCall;

    final uomsByPair = await uomsCall;

    bool isFound(ExcelImportRow row) =>
        pairs != null &&
        pairs.contains((key(row.line.article), key(row.line.shade)));

    // The pairs not found together: is the Article in JDE at all, and the
    // Shade? Each is checked on its own.
    final notFoundRows = pairs == null
        ? const <ExcelImportRow>[]
        : rowsToCheck.where((row) => !isFound(row)).toList();

    if (pairs == null) {
      for (final row in rowsToCheck) {
        _addWarning(row, 'Could not check the Article / Shade in JDE');
      }
    }
    // Not found together: JDE has no UOM for it either.
    await _lookUpImportUoms(
      rowsToCheck
          .where((row) => row.line.uom.isEmpty && (isFound(row) || pairs == null))
          .toList(),
      uomsByPair: uomsByPair,
    );


    // Unit prices, once per item (rows of the same item share it).
    final prices = <String, double?>{};

    Future<void> priceRows(Iterable<ExcelImportRow> rows) async {
      final items = rows
          .where((row) => row.isValid && row.line.uom.isNotEmpty)
          .map((row) => row.line.itemNumber)
          .where((item) => !prices.containsKey(item))
          .toSet();

      await _forEachConcurrently(items, (item) async {
        prices[item] = await _fetchUnitPrice(
          item,
          logLabel: '[BULK IMPORT] Unit price, item $item',
        );
      });
    }

    // The checks on their own and the prices of the rows found: together.
    final (articleExists, shadeExists, _) = await (
      _existsInItemMaster(
        controlId: 'F4101.SEG1',
        label: 'Article',
        values: notFoundRows.map((row) => key(row.line.article)).toSet(),
      ),
      _existsInItemMaster(
        controlId: 'F4101.SEG3',
        label: 'Shade',
        values: notFoundRows.map((row) => key(row.line.shade)).toSet(),
      ),
      priceRows(rowsToCheck.where((row) => !notFoundRows.contains(row))),
    ).wait;

    for (final row in rowsToCheck) {
      final article = key(row.line.article);

      final shade = key(row.line.shade);

      final String result;

      if (pairs == null) {
        result = 'JDE call failed (warning)';
      } else if (isFound(row)) {
        result = 'found in F4101';
      } else {
        final missing = [
          if (articleExists[article] == false) 'Article $article',
          if (shadeExists[shade] == false) 'Shade $shade',
        ];

        if (missing.isNotEmpty) {
          // Red, with Delete in the grid.
          row
            ..error = '${missing.join(' and ')} not found in JDE'
            ..isNotFoundInJde = true;

          result = '${missing.join(' and ')} NOT in F4101 (error)';
        } else {
          _addWarning(row, 'Article / Shade combination not found in JDE');

          result = 'Article and Shade in F4101, but not together (warning)';
        }
      }

      debugPrint(
        '[BULK IMPORT] Row ${row.rowNumber} Article "$article" + Shade '
        '"$shade": $result'
        '${row.line.uom.isEmpty ? '' : ', UOM ${row.line.uom}'}',
      );
    }

    // A combination not found but uploaded as is (its UOM from the sheet).
    await priceRows(notFoundRows);

    for (final row in rowsToCheck) {
      if (!row.isValid || row.line.uom.isEmpty) {
        continue;
      }

      final unitPrice = prices[row.line.itemNumber];

      // No price is not an error: the line goes without one.
      if (unitPrice != null && unitPrice > 0) {
        row.unitPrice = unitPrice;
      }

      debugPrint(
        '[BULK IMPORT] Row ${row.rowNumber} unit price: '
        '${row.unitPrice ?? 'none from JDE, uploaded without a price'}',
      );
    }

    debugPrint(
      '[BULK IMPORT] JDE checks of ${rowsToCheck.length} row(s) took '
      '${stopwatch.elapsedMilliseconds} ms (${prices.length} unit price '
      'call(s))',
    );
  }

  /// Adds [text] to [row]'s yellow JDE warning (shown before any Quantity
  /// problem).
  void _addWarning(ExcelImportRow row, String text) {
    final warning = row.warning;

    row.warning = warning == null ? text : '$warning; $text';
  }

  /// For each of [values], whether the JDE item master has it in
  /// [controlId] on its own (Api.existsInItemMaster); null when the call
  /// failed.
  Future<Map<String, bool?>> _existsInItemMaster({
    required String controlId,
    required String label,
    required Set<String> values,
  }) async {
    final exists = <String, bool?>{};

    await _forEachConcurrently(values, (value) async {
      exists[value] = await Api.existsInItemMaster(
        controlId: controlId,
        value: value,
        logLabel: '[BULK IMPORT] $label check on its own ($controlId '
            '= $value)',
      );

      debugPrint(
        '[BULK IMPORT] $label "$value" on its own in F4101: '
        '${switch (exists[value]) {
          true => 'found',
          false => 'NOT found',
          null => 'JDE call failed',
        }}',
      );
    });

    return exists;
  }

  /// The UOM of each of [rows] from its Article and Shade, as the form picks
  /// it: the UOMs JDE has for the shade, kept to the article's catalog
  /// UOMs. One: used. Several: an error, the UOM to be entered in Fix.
  /// None: a warning, the line goes without a UOM.
  ///
  /// The JDE UOMs come from [uomsByPair] (one query for all rows,
  /// Api.fetchUomsForPairs); when that call failed, from one
  /// Api.fetchUomsForShade call per pair.
  Future<void> _lookUpImportUoms(
    List<ExcelImportRow> rows, {
    required Map<(String, String), List<String>>? uomsByPair,
  }) async {
    final uomsByItem = <(String, String), List<String>>{};

    final pairsToLookUp = rows
        .map((row) => (row.line.article.trim(), row.line.shade.trim()))
        .toSet();

    void keep((String, String) pair, List<String> jdeUoms) {
      final (article, shade) = pair;

      final catalogUoms = catalogController.orderItems
          .where((item) => item.article == article)
          .map((item) => item.uom)
          .toSet();

      final uoms = catalogUoms.isEmpty
          ? jdeUoms
          : jdeUoms.where(catalogUoms.contains).toList();

      uomsByItem[pair] = uoms;

      final jdeText = jdeUoms.isEmpty ? 'none' : jdeUoms.join(', ');

      final catalogText = catalogUoms.isEmpty
          ? ''
          : ', in the catalog ${uoms.isEmpty ? 'none' : uoms.join(', ')}';

      debugPrint(
        '[BULK IMPORT] UOM lookup (F4101 SEG2) for Article "$article" '
        '+ Shade "$shade": JDE $jdeText$catalogText',
      );
    }

    if (uomsByPair != null) {
      for (final pair in pairsToLookUp) {
        final (article, shade) = pair;

        keep(
          pair,
          uomsByPair[(article.toUpperCase(), shade.toUpperCase())] ??
              const <String>[],
        );
      }
    } else {
      // The one query failed: one call per pair, as the form does.
      await _forEachConcurrently(pairsToLookUp, (pair) async {
        final (article, shade) = pair;

        keep(
          pair,
          await Api.fetchUomsForShade(article: article, shade: shade),
        );
      });
    }

    for (final row in rows) {
      final uoms =
          uomsByItem[(row.line.article.trim(), row.line.shade.trim())] ??
              const <String>[];

      if (uoms.length == 1) {
        row
          ..line = row.line.copyWith(uom: uoms.first)
          ..uomLookedUp = true;
      } else if (uoms.isEmpty) {
        _addWarning(row, 'No UOM found in JDE for this Article / Shade');
      } else {
        row.error = 'Several UOMs for this Article / Shade '
            '(${uoms.join(', ')}): enter one in Fix';
      }
    }
  }

  /// TC Required ticked in the import dialog ([tcOffered]: the uploaded
  /// sheet all "R" articles): every line is a TC line. Otherwise, and for a
  /// sheet of normal or mixed articles, every line is a normal line.
  Future<void> _insertImportRows(
    List<ExcelImportRow> importRows, {
    required bool tcOffered,
    required String fileName,
  }) async {
    var lineNumber = _lastLineNumber;

    // All lines saved in one batch (one transaction): the table below the
    // form is drawn once, not once per line.
    final lines = <DraftTableCompanion>[];

    for (final importRow in importRows) {
      final excelLine = importRow.line;

      // A TC line only when every uploaded line is an "R" article; a
      // sheet mixed with other articles is a normal order.
      final isTcImportLine = tcOffered && importRow.isTcLineIn(importRows);

      lineNumber++;

      final catalogItem = catalogController.orderItem(
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

      lines.add(
        DraftTableCompanion.insert(
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
          billingType: isTcImportLine ? 'Plant' : '',
          remark: isTcImportLine ? DirectDeliveryTc.tcRequiredRemark : '',
          endUse: '',
          lab: '',
          lineNumber: lineNumber,
          orderNumber: orderNumber,
          orderType: 'BK',
          requestType: '',
          soldTo: _userController.rxUserDetail.value.soldToNumber,
          colorRemark: isTcImportLine ? DirectDeliveryTc.tcRequiredRemark : '',
          lastUpdated: DateTime.now(),
          // Marks the line as imported: cleared by the next import.
          qtxFileName: fileName,
          requestedDate: drift.Value(rxRequestedDate.value),
          poFileName: '',
          poFileBytes: drift.Value(null),
        ),
      );
    }

    await _database.batch(
      (batch) => batch.insertAll(
        _database.draftTable,
        lines,
        mode: drift.InsertMode.insertOrReplace,
      ),
    );
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
    rxUomWithDesc.value = bulkOrderLine.uom.trim().isEmpty
        ? ''
        : '${bulkOrderLine.uom} - ${orderReviewController.getUomDescription(bulkOrderLine.uom)}';
    rxShade.value = bulkOrderLine.shade;

    // A line imported without a UOM: its sheet's shade stays when a UOM is
    // picked, until the user changes the shade.
    _lineShadeToKeep =
        bulkOrderLine.uom.trim().isEmpty && bulkOrderLine.shade.isNotEmpty
            ? bulkOrderLine.shade
            : null;
    rxColor.value = bulkOrderLine.colorName;
    rxQuantity.value = bulkOrderLine.quantity.toString();
    rxRequestedDate.value = bulkOrderLine.requestedDate;
    rxPoFileName.value = bulkOrderLine.poFileName;
    rxPoNumber.value = bulkOrderLine.poNumber;
    rxPoFileBytes.value = bulkOrderLine.poFileBytes;
    rxUnitPrice.value = bulkOrderLine.unitPrice?.toString() ?? '';
    populateTc(bulkOrderLine);
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
