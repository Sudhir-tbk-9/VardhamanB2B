import 'package:vardhman_b2b/constants.dart';

class ExcelLine {
  final String merchandiser;
  final String poNumber;
  final String article;
  final String uom;
  final String shade;
  final String buyer;
  final String styleNo;
  final int quantity;
  final String lightSources;

  ExcelLine({
    required this.merchandiser,
    required this.poNumber,
    required this.article,
    required this.uom,
    required this.shade,
    required this.buyer,
    required this.styleNo,
    required this.quantity,
    required this.lightSources,
  });

  factory ExcelLine.fromCells(List<String> cells) {
    String cell(int index) => cells.elementAtOrNull(index)?.trim() ?? '';

    return ExcelLine(
      poNumber: cell(0),
      merchandiser: cell(1),
      buyer: cell(2),
      lightSources: cell(3),
      article: cell(4).toUpperCase(),
      uom: cell(5).toUpperCase(),
      shade: cell(6).toUpperCase(),
      styleNo: cell(7),
      quantity: parseQuantity(cell(8)),
    );
  }

  static int parseQuantity(String text) {
    final quantity = num.tryParse(text.trim());

    return quantity == null || quantity != quantity.truncate()
        ? 0
        : quantity.toInt();
  }

  ExcelLine copyWith({
    String? merchandiser,
    String? poNumber,
    String? article,
    String? uom,
    String? shade,
    String? buyer,
    String? styleNo,
    int? quantity,
    String? lightSources,
  }) {
    return ExcelLine(
      merchandiser: merchandiser ?? this.merchandiser,
      poNumber: poNumber ?? this.poNumber,
      article: article ?? this.article,
      uom: uom ?? this.uom,
      shade: shade ?? this.shade,
      buyer: buyer ?? this.buyer,
      styleNo: styleNo ?? this.styleNo,
      quantity: quantity ?? this.quantity,
      lightSources: lightSources ?? this.lightSources,
    );
  }

  List<String> get missingFields => [
        if (poNumber.isEmpty) 'PO Number',
        if (merchandiser.isEmpty) 'Merchandiser',
        if (buyer.isEmpty) 'Buyer',
        if (lightSources.isEmpty) 'Light Source',
        if (article.isEmpty) 'Article',
        if (uom.isEmpty) 'UOM',
        if (shade.isEmpty) 'Shade',
        if (quantity < 1) 'Quantity',
      ];

  bool get hasError => missingFields.isNotEmpty;

  bool get isBlank =>
      merchandiser.isEmpty &&
      poNumber.isEmpty &&
      article.isEmpty &&
      uom.isEmpty &&
      shade.isEmpty &&
      buyer.isEmpty &&
      styleNo.isEmpty &&
      quantity == 0 &&
      lightSources.isEmpty;

  String get itemNumber =>
      getItemNumber(article: article, uom: uom, shade: shade);
}

class ExcelImportRow {
  /// Row number as shown in the spreadsheet (header is row 1).
  final int rowNumber;

  ExcelLine line;

  String? error;

  double? unitPrice;

  ExcelImportRow({required this.rowNumber, required this.line});

  bool get isValid => error == null;
}
