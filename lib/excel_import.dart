import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';

class ExcelImport {
  /// 读取 Excel 第一列全部单元格文本（无表头），返回原始姓名列表。
  static List<String> readFirstColumn(String path) {
    final bytes = File(path).readAsBytesSync();
    final excel = Excel.decodeBytes(bytes);
    final result = <String>[];
    if (excel.tables.isEmpty) return result;
    final firstSheet = excel.tables.values.first;
    for (final row in firstSheet.rows) {
      if (row.isEmpty) continue;
      final v = row[0]?.value;
      if (v == null) continue;
      result.add(v.toString());
    }
    return result;
  }

  /// 生成只含姓名的一列 XLSX（无表头），与导入格式一致，可直接再导回。
  /// [names] 顺序即写表顺序：第一个在最上面（最早导入）。
  static Uint8List buildNamesXlsx(List<String> names) {
    final excel = Excel.createExcel();
    final sheetName = excel.tables.keys.first;
    final sheet = excel[sheetName];
    for (var i = 0; i < names.length; i++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i))
          .value = TextCellValue(names[i]);
    }
    final bytes = excel.encode();
    if (bytes == null) throw const FormatException('生成姓名表格失败');
    return Uint8List.fromList(bytes);
  }
}
