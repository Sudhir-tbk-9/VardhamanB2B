import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:vardhman_b2b/bulk/xls_reader.dart';
import 'package:xml/xml.dart';

const supportedSpreadsheetExtensions = ['xlsx', 'xls', 'csv'];

/// Reads the first sheet of an .xlsx, .xls or .csv file as rows of trimmed
/// strings.
///
/// The format is detected from the file content rather than the extension,
/// because WPS, LibreOffice, Google Sheets and web exports often save one
/// format under another's extension (e.g. an .xls that is really .xlsx,
/// HTML or tab-separated text). .xlsx falls back to a plain OOXML reader when
/// the `excel` package fails to decode the workbook.
List<List<String>> readSpreadsheetRows({
  required Uint8List bytes,
  required String fileName,
}) {
  final extension = fileName.split('.').last.toLowerCase();

  if (!supportedSpreadsheetExtensions.contains(extension)) {
    throw FormatException(
      'Unsupported file type .$extension. Please upload an .xlsx, .xls or .csv file.',
    );
  }

  if (bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
    try {
      return _readWithExcelPackage(bytes);
    } catch (e) {
      log('excel package could not decode $fileName, using OOXML reader - $e');

      return _readOoxml(bytes);
    }
  }

  if (isCompoundFile(bytes)) {
    return readXlsRows(bytes);
  }

  final text = _decodeText(bytes);

  if (RegExp(r'<table', caseSensitive: false).hasMatch(text)) {
    return _readHtmlTable(text);
  }

  return _readCsv(text);
}

String _decodeText(Uint8List bytes) {
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    final data = ByteData.sublistView(bytes);

    return String.fromCharCodes([
      for (var i = 2; i + 1 < bytes.length; i += 2)
        data.getUint16(i, Endian.little),
    ]);
  }

  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    final data = ByteData.sublistView(bytes);

    return String.fromCharCodes([
      for (var i = 2; i + 1 < bytes.length; i += 2)
        data.getUint16(i, Endian.big),
    ]);
  }

  String content;

  try {
    content = utf8.decode(bytes);
  } on FormatException {
    // Excel "CSV" is saved in the ANSI code page, not UTF-8.
    content = latin1.decode(bytes);
  }

  if (content.startsWith('﻿')) {
    content = content.substring(1);
  }

  return content;
}

String _htmlCellText(String html) => html
    .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&')
    .trim();

/// Web portals often export "Excel" files that are really an HTML table.
List<List<String>> _readHtmlTable(String html) {
  final table = RegExp(r'<table[\s\S]*?</table>', caseSensitive: false)
          .firstMatch(html)
          ?.group(0) ??
      html;

  return RegExp(r'<tr[^>]*>([\s\S]*?)</tr>', caseSensitive: false)
      .allMatches(table)
      .map(
        (row) => RegExp(r'<t[dh][^>]*>([\s\S]*?)</t[dh]>', caseSensitive: false)
            .allMatches(row.group(1)!)
            .map((cell) => _htmlCellText(cell.group(1)!))
            .toList(),
      )
      .toList();
}

String _normalizeNumber(num value) {
  if (value is double && value == value.truncateToDouble()) {
    return value.toInt().toString();
  }

  return value.toString();
}

List<List<String>> _readWithExcelPackage(Uint8List bytes) {
  final excel = Excel.decodeBytes(bytes);

  final sheet = excel.tables.values.first;

  return sheet.rows
      .map(
        (row) => row.map(
          (cell) {
            final value = cell?.value;

            return switch (value) {
              null => '',
              IntCellValue() => value.value.toString(),
              DoubleCellValue() => _normalizeNumber(value.value),
              // The package exposes the formula, not its cached result; the
              // OOXML reader reads the result.
              FormulaCellValue() => throw const FormatException(
                  'Formula cell, reading cached values instead.',
                ),
              _ => value.toString().trim(),
            };
          },
        ).toList(),
      )
      .toList();
}

int _columnIndex(String cellReference) {
  final letters = cellReference.replaceAll(RegExp(r'[^A-Za-z]'), '');

  var index = 0;

  for (final codeUnit in letters.toUpperCase().codeUnits) {
    index = index * 26 + (codeUnit - 64);
  }

  return index - 1;
}

Iterable<XmlElement> _elements(XmlNode node, String localName) =>
    node.descendants
        .whereType<XmlElement>()
        .where((element) => element.name.local == localName);

String _text(XmlNode node) =>
    _elements(node, 't').map((element) => element.innerText).join();

List<List<String>> _readOoxml(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);

  String? readEntry(String path) {
    final file = archive.findFile(path);

    return file == null
        ? null
        : utf8.decode(file.content as List<int>, allowMalformed: true);
  }

  final sheetPath = _firstSheetPath(readEntry) ??
      (archive.files
              .map((file) => file.name)
              .where((name) =>
                  name.startsWith('xl/worksheets/') && name.endsWith('.xml'))
              .toList()
            ..sort())
          .firstOrNull;

  final sheetXml = sheetPath == null ? null : readEntry(sheetPath);

  if (sheetXml == null) {
    throw const FormatException('No worksheet found in the file.');
  }

  final sharedStringsXml = readEntry('xl/sharedStrings.xml');

  final sharedStrings = sharedStringsXml == null
      ? <String>[]
      : _elements(XmlDocument.parse(sharedStringsXml), 'si')
          .map(_text)
          .toList();

  final rows = <List<String>>[];

  for (final rowElement in _elements(XmlDocument.parse(sheetXml), 'row')) {
    final cells = <String>[];

    for (final cellElement in rowElement.childElements
        .where((element) => element.name.local == 'c')) {
      final reference = cellElement.getAttribute('r');

      final index = reference == null ? cells.length : _columnIndex(reference);

      while (cells.length < index) {
        cells.add('');
      }

      final type = cellElement.getAttribute('t');

      final rawValue = _elements(cellElement, 'v').firstOrNull?.innerText ?? '';

      final value = switch (type) {
        's' =>
          sharedStrings.elementAtOrNull(int.tryParse(rawValue) ?? -1) ?? '',
        'inlineStr' => _text(cellElement),
        'str' || 'b' || 'e' => rawValue,
        _ => num.tryParse(rawValue) != null
            ? _normalizeNumber(num.parse(rawValue))
            : rawValue,
      };

      if (index < cells.length) {
        cells[index] = value.trim();
      } else {
        cells.add(value.trim());
      }
    }

    rows.add(cells);
  }

  return rows;
}

String? _firstSheetPath(String? Function(String path) readEntry) {
  final workbookXml = readEntry('xl/workbook.xml');

  final relsXml = readEntry('xl/_rels/workbook.xml.rels');

  if (workbookXml == null || relsXml == null) {
    return null;
  }

  final firstSheet =
      _elements(XmlDocument.parse(workbookXml), 'sheet').firstOrNull;

  final relationshipId = firstSheet?.attributes
      .firstWhereOrNull((attribute) => attribute.name.local == 'id')
      ?.value;

  final target = _elements(XmlDocument.parse(relsXml), 'Relationship')
      .firstWhereOrNull(
          (element) => element.getAttribute('Id') == relationshipId)
      ?.getAttribute('Target');

  if (target == null) {
    return null;
  }

  return target.startsWith('/') ? target.substring(1) : 'xl/$target';
}

List<List<String>> _readCsv(String content) {
  final firstLine = content.split('\n').first;

  // Comma, semicolon (European locales) or tab (WPS / Excel "Text" export).
  final delimiter = [',', ';', '\t'].reduce(
    (best, candidate) => candidate.allMatches(firstLine).length >
            best.allMatches(firstLine).length
        ? candidate
        : best,
  );

  final rows = <List<String>>[];

  var cells = <String>[];

  final cell = StringBuffer();

  var inQuotes = false;

  for (var i = 0; i < content.length; i++) {
    final char = content[i];

    if (inQuotes) {
      if (char == '"') {
        if (i + 1 < content.length && content[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cell.write(char);
      }
    } else if (char == '"') {
      inQuotes = true;
    } else if (char == delimiter) {
      cells.add(cell.toString().trim());
      cell.clear();
    } else if (char == '\n' || char == '\r') {
      if (char == '\r' && i + 1 < content.length && content[i + 1] == '\n') {
        i++;
      }

      cells.add(cell.toString().trim());
      cell.clear();
      rows.add(cells);
      cells = <String>[];
    } else {
      cell.write(char);
    }
  }

  if (cell.isNotEmpty || cells.isNotEmpty) {
    cells.add(cell.toString().trim());
    rows.add(cells);
  }

  return rows;
}

extension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) {
        return element;
      }
    }

    return null;
  }
}
