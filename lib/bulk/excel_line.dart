import 'package:vardhman_b2b/constants.dart';

/// Where each field is in a Bulk import sheet. The sample file
/// ("Stitch Connect Orders.xlsx", sheet bulk_csv_demo) has, in this order:
///
/// po_no | Merchandiser | buyer_name | light_sources | article | shade |
/// style_no | quantity
///
/// The header row is read by name, so a sheet whose columns are in another
/// order, or that still has a uom column (or a Sr. No. column, ignored)
/// imports too. Without a recognised header the order above is used.
class ExcelColumns {
  final int poNumber;
  final int merchandiser;
  final int buyer;
  final int lightSources;
  final int article;
  final int shade;
  final int styleNo;
  final int quantity;

  /// Null when the sheet has no uom column: the UOM is then looked up from
  /// the Article and Shade.
  final int? uom;

  /// The header row as read, to skip it when the sheet repeats it.
  final List<String> headerCells;

  const ExcelColumns({
    required this.poNumber,
    required this.merchandiser,
    required this.buyer,
    required this.lightSources,
    required this.article,
    required this.shade,
    required this.styleNo,
    required this.quantity,
    this.uom,
    this.headerCells = const [],
  });

  /// The sample file's column order.
  static const standard = ExcelColumns(
    poNumber: 0,
    merchandiser: 1,
    buyer: 2,
    lightSources: 3,
    article: 4,
    shade: 5,
    styleNo: 6,
    quantity: 7,
  );

  /// Header names (lower case, without spaces, "_", "." or "-") per field.
  static const _names = {
    'poNumber': ['pono', 'ponumber', 'po'],
    'merchandiser': ['merchandiser', 'merchandisername'],
    'buyer': ['buyername', 'buyer'],
    'lightSources': ['lightsources', 'lightsource'],
    'article': ['article', 'articleno'],
    'shade': ['shade', 'shadeno'],
    'styleNo': ['styleno', 'style', 'stylenumber'],
    'quantity': ['quantity', 'qty'],
    'uom': ['uom'],
  };

  static String _normalize(String cell) =>
      cell.toLowerCase().replaceAll(RegExp(r'[\s_.\-]'), '');

  /// The columns named in [headerCells], or null when it is not a header
  /// row (no Article, Shade and Quantity column names).
  static ExcelColumns? fromHeader(List<String> headerCells) {
    final normalized = headerCells.map(_normalize).toList();

    int? indexOf(String field) {
      for (final name in _names[field]!) {
        final index = normalized.indexOf(name);

        if (index != -1) {
          return index;
        }
      }

      return null;
    }

    final article = indexOf('article');
    final shade = indexOf('shade');
    final quantity = indexOf('quantity');

    if (article == null || shade == null || quantity == null) {
      return null;
    }

    // A column not in the sheet reads as empty.
    const absent = -1;

    return ExcelColumns(
      poNumber: indexOf('poNumber') ?? absent,
      merchandiser: indexOf('merchandiser') ?? absent,
      buyer: indexOf('buyer') ?? absent,
      lightSources: indexOf('lightSources') ?? absent,
      article: article,
      shade: shade,
      styleNo: indexOf('styleNo') ?? absent,
      quantity: quantity,
      uom: indexOf('uom'),
      headerCells: normalized,
    );
  }

  /// Whether [cells] is the header row again (a sheet pasted together).
  bool isHeaderRow(List<String> cells) {
    if (headerCells.isEmpty) {
      return ExcelColumns.fromHeader(cells) != null;
    }

    final normalized = cells.map(_normalize).toList();

    return normalized.elementAtOrNull(article) == headerCells[article] &&
        normalized.elementAtOrNull(shade) == headerCells[shade] &&
        normalized.elementAtOrNull(quantity) == headerCells[quantity];
  }
}

class ExcelLine {
  final String merchandiser;
  final String poNumber;
  final String article;

  /// From the sheet's uom column when it has one, otherwise looked up from
  /// the Article and Shade (as the form does, Api.fetchUomsForShade).
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

  factory ExcelLine.fromCells(
    List<String> cells, {
    ExcelColumns columns = ExcelColumns.standard,
  }) {
    String cell(int? index) => index == null || index < 0
        ? ''
        : cells.elementAtOrNull(index)?.trim() ?? '';

    return ExcelLine(
      poNumber: cell(columns.poNumber),
      merchandiser: cell(columns.merchandiser),
      buyer: cell(columns.buyer),
      lightSources: cell(columns.lightSources),
      article: cell(columns.article).toUpperCase(),
      uom: cell(columns.uom).toUpperCase(),
      shade: cell(columns.shade).toUpperCase(),
      styleNo: cell(columns.styleNo),
      quantity: parseQuantity(cell(columns.quantity)),
      quantityText: cell(columns.quantity),
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

  /// Fields a line cannot be ordered without. The UOM is not one: it is
  /// looked up from the Article and Shade.
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
  /// Position of the line in the import list: 1, 2, 3… in display order,
  /// whatever serial number the sheet has (empty and repeated header rows
  /// are not counted).
  final int rowNumber;

  ExcelLine line;

  /// Why the line cannot be ordered (no Article, Shade or Quantity, a
  /// Quantity under 1, an article the order or segment does not take, or a
  /// UOM to choose), or null. Lines with an error are shown in red and not
  /// uploaded.
  String? error;

  /// A note that does not stop the upload (the Article / Shade combination
  /// not found in JDE), or null. Shown in yellow; the line is valid.
  String? warning;

  /// JDE unit price, or null when JDE has none: the line is uploaded
  /// without one, as from the form.
  double? unitPrice;

  /// Whether the last validation found the line valid; it is not checked
  /// again until it is edited.
  bool isChecked = false;

  /// Whether [line]'s UOM was looked up from its Article and Shade (not
  /// from the sheet or entered in Fix): looked up again when re-validated.
  bool uomLookedUp = false;

  ExcelImportRow({required this.rowNumber, required this.line});

  bool get isValid => error == null;

  bool get hasWarning => isValid && warning != null;
}

/// The order lines of an import sheet, numbered 1, 2, 3… in display order
/// whatever serial number the sheet has. The first non-empty row is the
/// header when its column names are recognised (it then says where each
/// field is; otherwise the sample's column order is used and the row is a
/// line). Empty rows and repeated header rows are skipped.
List<ExcelImportRow> importRowsFromSheet(List<List<String>> sheetRows) {
  final headerIndex = sheetRows.indexWhere(
    (cells) => cells.any((cell) => cell.trim().isNotEmpty),
  );

  final header = headerIndex == -1
      ? null
      : ExcelColumns.fromHeader(sheetRows[headerIndex]);

  final columns = header ?? ExcelColumns.standard;

  final importRows = <ExcelImportRow>[];

  for (var i = header == null ? 0 : headerIndex + 1;
      i < sheetRows.length;
      i++) {
    if (columns.isHeaderRow(sheetRows[i])) {
      continue;
    }

    final line = ExcelLine.fromCells(sheetRows[i], columns: columns);

    if (!line.isBlank) {
      importRows.add(
        ExcelImportRow(rowNumber: importRows.length + 1, line: line),
      );
    }
  }

  return importRows;
}
