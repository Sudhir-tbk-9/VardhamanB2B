import 'dart:convert';
import 'dart:typed_data';

/// Reads the first worksheet of a legacy binary Excel (.xls, BIFF8 / BIFF5)
/// workbook as rows of trimmed strings.
///
/// The workbook is an OLE2 compound file; its `Workbook` (or `Book`) stream
/// holds the BIFF records. Only cell values are read; formatting is ignored.
List<List<String>> readXlsRows(Uint8List bytes) {
  final stream = _CompoundFile(bytes).readStream(['Workbook', 'Book']);

  if (stream == null) {
    throw const FormatException('No workbook found in the .xls file.');
  }

  return _BiffReader(stream).readFirstSheet();
}

bool isCompoundFile(Uint8List bytes) =>
    bytes.length >= 8 &&
    bytes[0] == 0xD0 &&
    bytes[1] == 0xCF &&
    bytes[2] == 0x11 &&
    bytes[3] == 0xE0 &&
    bytes[4] == 0xA1 &&
    bytes[5] == 0xB1 &&
    bytes[6] == 0x1A &&
    bytes[7] == 0xE1;

const _endOfChain = 0xFFFFFFFE;

const _freeSector = 0xFFFFFFFF;

class _CompoundFile {
  final Uint8List bytes;

  final ByteData data;

  late final int sectorSize = 1 << data.getUint16(0x1E, Endian.little);

  late final int miniSectorSize = 1 << data.getUint16(0x20, Endian.little);

  late final int miniStreamCutoff = data.getUint32(0x38, Endian.little);

  late final List<int> fat = _readFat();

  _CompoundFile(this.bytes) : data = ByteData.sublistView(bytes) {
    if (!isCompoundFile(bytes)) {
      throw const FormatException('Not a valid .xls file.');
    }
  }

  int _sectorOffset(int sector) => (sector + 1) * sectorSize;

  int _uint32At(int offset) => offset + 4 <= bytes.length
      ? data.getUint32(offset, Endian.little)
      : _endOfChain;

  List<int> _readFat() {
    final fatSectors = <int>[];

    for (var i = 0; i < 109; i++) {
      final sector = _uint32At(0x4C + i * 4);

      if (sector != _freeSector && sector != _endOfChain) {
        fatSectors.add(sector);
      }
    }

    var difatSector = _uint32At(0x44);

    final entriesPerSector = sectorSize ~/ 4;

    var guard = 0;

    while (difatSector != _endOfChain &&
        difatSector != _freeSector &&
        guard++ < 10000) {
      final offset = _sectorOffset(difatSector);

      for (var i = 0; i < entriesPerSector - 1; i++) {
        final sector = _uint32At(offset + i * 4);

        if (sector != _freeSector && sector != _endOfChain) {
          fatSectors.add(sector);
        }
      }

      difatSector = _uint32At(offset + (entriesPerSector - 1) * 4);
    }

    final fat = <int>[];

    for (final sector in fatSectors) {
      final offset = _sectorOffset(sector);

      for (var i = 0; i < entriesPerSector; i++) {
        fat.add(_uint32At(offset + i * 4));
      }
    }

    return fat;
  }

  List<int> _chain(int start, List<int> table) {
    final chain = <int>[];

    var sector = start;

    while (sector != _endOfChain &&
        sector != _freeSector &&
        sector < table.length &&
        chain.length <= table.length) {
      chain.add(sector);

      sector = table[sector];
    }

    return chain;
  }

  Uint8List _readChain(int start, int size) {
    final out = BytesBuilder(copy: false);

    for (final sector in _chain(start, fat)) {
      final offset = _sectorOffset(sector);

      final end = (offset + sectorSize).clamp(0, bytes.length);

      if (offset < end) {
        out.add(Uint8List.sublistView(bytes, offset, end));
      }
    }

    final all = out.takeBytes();

    return size < all.length ? Uint8List.sublistView(all, 0, size) : all;
  }

  Uint8List? readStream(List<String> names) {
    final root = _readChain(data.getUint32(0x30, Endian.little), 1 << 30);

    final rootData = ByteData.sublistView(root);

    int? rootStart, rootSize;

    for (var offset = 0; offset + 128 <= root.length; offset += 128) {
      final nameLength = rootData.getUint16(offset + 64, Endian.little);

      final type = root[offset + 66];

      if (type == 0 || nameLength < 2 || nameLength > 64) {
        continue;
      }

      final name = String.fromCharCodes(
        Uint16List.fromList([
          for (var i = 0; i < nameLength ~/ 2 - 1; i++)
            rootData.getUint16(offset + i * 2, Endian.little),
        ]),
      );

      final start = rootData.getUint32(offset + 116, Endian.little);

      final size = rootData.getUint32(offset + 120, Endian.little);

      if (type == 5) {
        rootStart = start;

        rootSize = size;
      } else if (type == 2 && names.contains(name)) {
        if (size >= miniStreamCutoff) {
          return _readChain(start, size);
        }

        return _readMiniStream(start, size, rootStart, rootSize);
      }
    }

    return null;
  }

  Uint8List _readMiniStream(
      int start, int size, int? rootStart, int? rootSize) {
    if (rootStart == null || rootSize == null) {
      throw const FormatException('Corrupt .xls file.');
    }

    final miniStream = _readChain(rootStart, rootSize);

    final miniFatBytes = _readChain(
      data.getUint32(0x3C, Endian.little),
      data.getUint32(0x40, Endian.little) * sectorSize,
    );

    final miniFatData = ByteData.sublistView(miniFatBytes);

    final miniFat = [
      for (var i = 0; i + 4 <= miniFatBytes.length; i += 4)
        miniFatData.getUint32(i, Endian.little),
    ];

    final out = BytesBuilder(copy: false);

    for (final sector in _chain(start, miniFat)) {
      final offset = sector * miniSectorSize;

      final end = (offset + miniSectorSize).clamp(0, miniStream.length);

      if (offset < end) {
        out.add(Uint8List.sublistView(miniStream, offset, end));
      }
    }

    final all = out.takeBytes();

    return size < all.length ? Uint8List.sublistView(all, 0, size) : all;
  }
}

class _Record {
  final int id;

  final Uint8List data;

  _Record(this.id, this.data);
}

class _BiffReader {
  final Uint8List stream;

  final ByteData data;

  bool _isBiff8 = true;

  final _sharedStrings = <String>[];

  _BiffReader(this.stream) : data = ByteData.sublistView(stream);

  _Record? _recordAt(int offset) {
    if (offset + 4 > stream.length) {
      return null;
    }

    final id = data.getUint16(offset, Endian.little);

    final length = data.getUint16(offset + 2, Endian.little);

    final end = (offset + 4 + length).clamp(0, stream.length);

    return _Record(id, Uint8List.sublistView(stream, offset + 4, end));
  }

  List<List<String>> readFirstSheet() {
    final sheetOffsets = <int>[];

    var offset = 0;

    // Workbook globals: BOF, SST (+ CONTINUE), BOUNDSHEET ... EOF.
    while (true) {
      final record = _recordAt(offset);

      if (record == null) {
        break;
      }

      offset += 4 + record.data.length;

      final recordData = ByteData.sublistView(record.data);

      if (record.id == 0x0809 && record.data.length >= 2) {
        _isBiff8 = recordData.getUint16(0, Endian.little) >= 0x0600;
      } else if (record.id == 0x0085 && record.data.length >= 6) {
        // BOUNDSHEET: keep worksheets (type 0) only.
        if (record.data[5] == 0) {
          sheetOffsets.add(recordData.getUint32(0, Endian.little));
        }
      } else if (record.id == 0x00FC) {
        final parts = [record.data];

        while (true) {
          final next = _recordAt(offset);

          if (next == null || next.id != 0x003C) {
            break;
          }

          parts.add(next.data);

          offset += 4 + next.data.length;
        }

        _readSharedStrings(parts);
      } else if (record.id == 0x000A) {
        break;
      }
    }

    if (sheetOffsets.isEmpty) {
      throw const FormatException('No worksheet found in the .xls file.');
    }

    return _readSheet(sheetOffsets.first);
  }

  void _readSharedStrings(List<Uint8List> parts) {
    final reader = _ContinuedReader(parts);

    reader.skip(4);

    final count = reader.uint32();

    for (var i = 0; i < count && !reader.isAtEnd; i++) {
      _sharedStrings.add(reader.unicodeString());
    }
  }

  List<List<String>> _readSheet(int start) {
    final cells = <int, Map<int, String>>{};

    void put(int row, int column, String value) {
      (cells[row] ??= {})[column] = value.trim();
    }

    var offset = start;

    var depth = 0;

    int? pendingFormulaRow, pendingFormulaColumn;

    while (true) {
      final record = _recordAt(offset);

      if (record == null) {
        break;
      }

      offset += 4 + record.data.length;

      final d = ByteData.sublistView(record.data);

      final length = record.data.length;

      int row() => d.getUint16(0, Endian.little);

      int column() => d.getUint16(2, Endian.little);

      switch (record.id) {
        case 0x0809:
          depth++;
        case 0x000A:
          depth--;
        case 0x00FD when length >= 10: // LABELSST
          final index = d.getUint32(6, Endian.little);

          put(row(), column(), _sharedStrings.elementAtOrNull(index) ?? '');
        case 0x0204 when length >= 8: // LABEL
          put(row(), column(), _plainString(record.data, 6));
        case 0x00D6 when length >= 8: // RSTRING (BIFF5)
          put(row(), column(), _plainString(record.data, 6));
        case 0x0203 when length >= 14: // NUMBER
          put(row(), column(), _formatNumber(d.getFloat64(6, Endian.little)));
        case 0x027E when length >= 10: // RK
          put(row(), column(),
              _formatNumber(_rk(d.getUint32(6, Endian.little))));
        case 0x00BD when length >= 6: // MULRK
          final first = column();

          final count = (length - 6) ~/ 6;

          for (var i = 0; i < count; i++) {
            put(
              row(),
              first + i,
              _formatNumber(_rk(d.getUint32(4 + i * 6 + 2, Endian.little))),
            );
          }
        case 0x0205 when length >= 8: // BOOLERR
          if (record.data[7] == 0) {
            put(row(), column(), record.data[6] == 0 ? 'FALSE' : 'TRUE');
          }
        case 0x0006 when length >= 14: // FORMULA, cached result
          if (d.getUint16(12, Endian.little) != 0xFFFF) {
            put(row(), column(), _formatNumber(d.getFloat64(6, Endian.little)));
          } else if (record.data[6] == 0) {
            pendingFormulaRow = row();

            pendingFormulaColumn = column();
          } else if (record.data[6] == 1) {
            put(row(), column(), record.data[8] == 0 ? 'FALSE' : 'TRUE');
          }
        case 0x0207: // STRING, result of the preceding FORMULA
          if (pendingFormulaRow != null && pendingFormulaColumn != null) {
            put(pendingFormulaRow, pendingFormulaColumn,
                _plainString(record.data, 0));
          }

          pendingFormulaRow = null;

          pendingFormulaColumn = null;
      }

      if (depth <= 0) {
        break;
      }
    }

    if (cells.isEmpty) {
      return [];
    }

    final lastRow = cells.keys.reduce((a, b) => a > b ? a : b);

    return [
      for (var r = 0; r <= lastRow; r++)
        if (cells[r] case final rowCells?)
          [
            for (var c = 0;
                c <= rowCells.keys.reduce((a, b) => a > b ? a : b);
                c++)
              rowCells[c] ?? '',
          ]
        else
          <String>[],
    ];
  }

  /// XLUnicodeString (BIFF8) or byte string (BIFF5) starting at [offset].
  String _plainString(Uint8List bytes, int offset) {
    if (offset + 2 > bytes.length) {
      return '';
    }

    final length = bytes[offset] | (bytes[offset + 1] << 8);

    if (!_isBiff8) {
      final end = (offset + 2 + length).clamp(0, bytes.length);

      return latin1.decode(bytes.sublist(offset + 2, end));
    }

    if (offset + 3 > bytes.length) {
      return '';
    }

    final highByte = bytes[offset + 2] & 0x01 != 0;

    final start = offset + 3;

    if (highByte) {
      final end = (start + length * 2).clamp(0, bytes.length);

      final d = ByteData.sublistView(bytes, start, end);

      return String.fromCharCodes([
        for (var i = 0; i + 1 < end - start; i += 2)
          d.getUint16(i, Endian.little),
      ]);
    }

    final end = (start + length).clamp(0, bytes.length);

    return latin1.decode(bytes.sublist(start, end));
  }
}

double _rk(int rk) {
  double value;

  if (rk & 0x02 != 0) {
    value = (rk.toSigned(32) >> 2).toDouble();
  } else {
    final bits = ByteData(8)..setUint32(4, rk & 0xFFFFFFFC, Endian.little);

    value = bits.getFloat64(0, Endian.little);
  }

  return rk & 0x01 != 0 ? value / 100 : value;
}

String _formatNumber(double value) {
  if (value == value.truncateToDouble() && value.abs() < 1e15) {
    return value.toInt().toString();
  }

  return value.toString();
}

/// Reads the SST, whose strings may be split across CONTINUE records; each
/// CONTINUE that splits character data starts with a fresh high-byte flag.
class _ContinuedReader {
  final List<Uint8List> parts;

  int _part = 0;

  int _offset = 0;

  _ContinuedReader(this.parts);

  bool get isAtEnd =>
      _part >= parts.length ||
      (_part == parts.length - 1 && _offset >= parts[_part].length);

  void _advanceIfNeeded() {
    while (_part < parts.length && _offset >= parts[_part].length) {
      _part++;

      _offset = 0;
    }
  }

  int byte() {
    _advanceIfNeeded();

    if (_part >= parts.length) {
      throw const FormatException('Unexpected end of .xls string table.');
    }

    return parts[_part][_offset++];
  }

  int uint16() => byte() | (byte() << 8);

  int uint32() => uint16() | (uint16() << 16);

  void skip(int count) {
    for (var i = 0; i < count; i++) {
      byte();
    }
  }

  String unicodeString() {
    final length = uint16();

    final flags = byte();

    var highByte = flags & 0x01 != 0;

    final runs = flags & 0x08 != 0 ? uint16() : 0;

    final extLength = flags & 0x04 != 0 ? uint32() : 0;

    final codeUnits = <int>[];

    while (codeUnits.length < length) {
      if (_offset >= parts[_part].length) {
        // Character data continues in the next CONTINUE record.
        _part++;

        _offset = 0;

        if (_part >= parts.length) {
          break;
        }

        highByte = byte() & 0x01 != 0;
      }

      codeUnits.add(highByte ? uint16() : byte());
    }

    skip(runs * 4 + extLength);

    return String.fromCharCodes(codeUnits);
  }
}
