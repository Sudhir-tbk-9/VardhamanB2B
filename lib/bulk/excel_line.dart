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

  /// Quantity as written in the file or the Fix modal, so an empty cell
  /// ("Missing Quantity") and a 0 (or text) are told apart.
  final String quantityText;

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
    String? quantityText,
  }) : quantityText = quantityText ?? (quantity == 0 ? '' : '$quantity');

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
      quantityText: cell(8),
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
    String? quantityText,
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
      quantityText:
          quantityText ?? (quantity == null ? this.quantityText : null),
      lightSources: lightSources ?? this.lightSources,
    );
  }

  /// Fields a line cannot be ordered without.
  List<String> get missingRequiredFields => [
        if (article.isEmpty) 'Article',
        if (shade.isEmpty) 'Shade',
        if (quantityText.isEmpty) 'Quantity',
      ];

  /// Why a Quantity that is given cannot be ordered (0, negative, not a
  /// whole number), or null. An order line needs at least 1.
  String? get quantityError => quantityText.isNotEmpty && quantity < 1
      ? 'Quantity must be at least 1 (is "$quantityText")'
      : null;

  bool get hasError =>
      missingRequiredFields.isNotEmpty || quantityError != null;

  bool get isBlank =>
      merchandiser.isEmpty &&
      poNumber.isEmpty &&
      article.isEmpty &&
      uom.isEmpty &&
      shade.isEmpty &&
      buyer.isEmpty &&
      styleNo.isEmpty &&
      quantityText.isEmpty &&
      lightSources.isEmpty;

  String get itemNumber =>
      getItemNumber(article: article, uom: uom, shade: shade);
}

class ExcelImportRow {
  /// Number of the order line in the file: 1 for the first line under the
  /// column header.
  final int rowNumber;

  ExcelLine line;

  /// Why the line cannot be ordered (no Article, Shade or Quantity, or the
  /// Article / Shade not in JDE), or null. Lines with an error are shown in
  /// red and not uploaded; the others are shown in green and uploaded.
  String? error;

  /// JDE unit price, or null when JDE has none: the line is uploaded
  /// without one, as from the form.
  double? unitPrice;

  /// Whether the last validation found the line valid; it is not checked
  /// again until it is edited.
  bool isChecked = false;

  ExcelImportRow({required this.rowNumber, required this.line});

  bool get isValid => error == null;
}
