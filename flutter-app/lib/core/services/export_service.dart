import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:health_center_app/core/models/health_data.dart';
import 'package:health_center_app/core/models/family_member.dart';

/// 导出格式枚举
enum ExportFormat {
  csv('CSV表格', '.csv'),
  json('JSON数据', '.json'),
  excel('Excel表格', '.xlsx');

  final String label;
  final String extension;
  const ExportFormat(this.label, this.extension);
}

/// 导出时间范围
enum ExportTimeRange {
  last7Days('最近7天'),
  last30Days('最近30天'),
  last3Months('最近3个月'),
  all('全部数据');

  final String label;
  const ExportTimeRange(this.label);

  DateTime getStartTime() {
    final now = DateTime.now();
    switch (this) {
      case ExportTimeRange.last7Days:
        return now.subtract(const Duration(days: 7));
      case ExportTimeRange.last30Days:
        return now.subtract(const Duration(days: 30));
      case ExportTimeRange.last3Months:
        return now.subtract(const Duration(days: 90));
      case ExportTimeRange.all:
        return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }
}

/// 导出服务
class ExportService {
  /// 单例模式
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  /// 日期格式化器
  static final _dateFormatter = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final _fileDateFormatter = DateFormat('yyyyMMdd_HHmmss');

  /// 导出健康数据
  ExportResult exportHealthData({
    required List<HealthData> data,
    required List<FamilyMember> members,
    required ExportFormat format,
    String? memberId,
  }) {
    // 过滤数据
    final filteredData = memberId == null || memberId.isEmpty
        ? data
        : data.where((d) => d.memberId == memberId).toList();

    if (filteredData.isEmpty) {
      return ExportResult(
        success: false,
        errorMessage: '没有可导出的数据',
      );
    }

    try {
      String content;
      String fileName;

      switch (format) {
        case ExportFormat.csv:
          content = _exportToCsv(filteredData, members);
          fileName = _generateFileName('csv');
          break;
        case ExportFormat.json:
          content = _exportToJson(filteredData, members);
          fileName = _generateFileName('json');
          break;
        case ExportFormat.excel:
          final excelBytes = _exportToExcel(filteredData, members);
          return ExportResult(
            success: true,
            content: String.fromCharCodes(excelBytes),
            fileName: _generateFileName('xlsx'),
            recordCount: filteredData.length,
            isBinary: true,
          );
      }

      return ExportResult(
        success: true,
        content: content,
        fileName: fileName,
        recordCount: filteredData.length,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        errorMessage: '导出失败: $e',
      );
    }
  }

  /// 导出为CSV格式
  String _exportToCsv(List<HealthData> data, List<FamilyMember> members) {
    final buffer = StringBuffer();

    // CSV BOM（确保Excel正确识别中文）
    buffer.write('\uFEFF');

    // 表头
    buffer.writeln('记录时间,成员姓名,关系,数据类型,数值1,数值2,单位,备注');

    // 数据行
    for (final item in data) {
      final member = members.firstWhere(
        (m) => m.id == item.memberId,
        orElse: () => FamilyMember(
          id: '',
          name: '未知',
          gender: 1,
          relation: MemberRelation.other,
          role: MemberRole.member,
          createTime: DateTime.now(),
        ),
      );

      final recordTime = _dateFormatter.format(item.recordTime);
      final memberName = member.name;
      final relation = member.relation.label;
      final dataType = item.type.label;
      final value1 = item.value1;
      final value2 = item.value2;
      final unit = item.type.unit;
      final note = item.notes ?? '';

      // 处理CSV中的逗号和引号
      String escapeCsvField(String field) {
        if (field.contains(',') || field.contains('"') || field.contains('\n')) {
          return '"${field.replaceAll('"', '""')}"';
        }
        return field;
      }

      buffer.writeln(
        '${escapeCsvField(recordTime)},'
        '${escapeCsvField(memberName)},'
        '${escapeCsvField(relation)},'
        '${escapeCsvField(dataType)},'
        '${escapeCsvField(value1.toString())},'
        '${escapeCsvField(value2.toString())},'
        '${escapeCsvField(unit)},'
        '${escapeCsvField(note)}',
      );
    }

    return buffer.toString();
  }

  /// 导出为Excel格式
  Uint8List _exportToExcel(List<HealthData> data, List<FamilyMember> members) {
    final excel = Excel.createExcel();

    // 删除默认sheet
    excel.delete('Sheet1');

    // 按数据类型分组
    final groupedData = <HealthDataType, List<HealthData>>{};
    for (final item in data) {
      groupedData.putIfAbsent(item.type, () => []).add(item);
    }

    // 为每种数据类型创建一个Sheet
    for (final entry in groupedData.entries) {
      final type = entry.key;
      final typeData = entry.value;

      // Sheet名称不能超过31个字符
      final sheetName = type.label.length > 31
          ? type.label.substring(0, 31)
          : type.label;

      final sheet = excel[sheetName];

      // 表头样式
      final headerCellStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.white,
        backgroundColorHex: ExcelColor.fromHexString('#4CAF50'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      // 表头
      final headers = ['记录时间', '成员姓名', '关系', '数值1', '数值2', '单位', '备注'];
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = headerCellStyle;
      }

      // 数据行
      for (int i = 0; i < typeData.length; i++) {
        final item = typeData[i];
        final rowIndex = i + 1;

        final member = members.firstWhere(
          (m) => m.id == item.memberId,
          orElse: () => FamilyMember(
            id: '',
            name: '未知',
            gender: 1,
            relation: MemberRelation.other,
            role: MemberRole.member,
            createTime: DateTime.now(),
          ),
        );

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
            .value = TextCellValue(_dateFormatter.format(item.recordTime));
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
            .value = TextCellValue(member.name);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
            .value = TextCellValue(member.relation.label);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
            .value = TextCellValue(item.value1.toString());
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
            .value = TextCellValue(item.value2?.toString() ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
            .value = TextCellValue(item.type.unit);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex))
            .value = TextCellValue(item.notes ?? '');
      }
    }

    // 创建汇总Sheet
    if (groupedData.length > 1) {
      final summarySheet = excel['汇总'];
      final headerCellStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.white,
        backgroundColorHex: ExcelColor.fromHexString('#4CAF50'),
        horizontalAlign: HorizontalAlign.Center,
      );

      final headers = ['数据类型', '记录数'];
      for (int i = 0; i < headers.length; i++) {
        final cell = summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = headerCellStyle;
      }

      int rowIndex = 1;
      for (final entry in groupedData.entries) {
        summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
            .value = TextCellValue(entry.key.label);
        summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
            .value = TextCellValue(entry.value.length.toString());
        rowIndex++;
      }
    }

    final bytes = excel.encode();
    return bytes != null ? Uint8List.fromList(bytes) : Uint8List(0);
  }

  /// 导出为JSON格式
  String _exportToJson(List<HealthData> data, List<FamilyMember> members) {
    final exportData = {
      'exportTime': _dateFormatter.format(DateTime.now()),
      'totalRecords': data.length,
      'data': data.map((item) {
        final member = members.firstWhere(
          (m) => m.id == item.memberId,
          orElse: () => FamilyMember(
            id: '',
            name: '未知',
            gender: 1,
            relation: MemberRelation.other,
            role: MemberRole.member,
            createTime: DateTime.now(),
          ),
        );

        return {
          'id': item.id,
          'recordTime': _dateFormatter.format(item.recordTime),
          'member': {
            'id': member.id,
            'name': member.name,
            'relation': member.relation.label,
          },
          'dataType': item.type.label,
          'values': {
            'value1': item.value1,
            'value2': item.value2,
            'unit': item.type.unit,
          },
          'note': item.notes,
        };
      }).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  /// 生成文件名
  String _generateFileName(String extension) {
    final timestamp = _fileDateFormatter.format(DateTime.now());
    return '健康数据_$timestamp.$extension';
  }

  /// 获取导出预览（前N条记录）
  String getPreview({
    required List<HealthData> data,
    required List<FamilyMember> members,
    required ExportFormat format,
    int maxRecords = 5,
  }) {
    final previewData = data.take(maxRecords).toList();

    switch (format) {
      case ExportFormat.csv:
        return _exportToCsv(previewData, members);
      case ExportFormat.json:
        return _exportToJson(previewData, members);
      case ExportFormat.excel:
        // Excel预览用CSV代替
        return _exportToCsv(previewData, members);
    }
  }

  /// 计算导出统计信息
  ExportStats calculateStats({
    required List<HealthData> data,
    required String? memberId,
    required DateTime? startTime,
    required DateTime? endTime,
  }) {
    var filtered = data;

    if (memberId != null && memberId.isNotEmpty) {
      filtered = filtered.where((d) => d.memberId == memberId).toList();
    }

    if (startTime != null) {
      filtered = filtered.where((d) => d.recordTime.isAfter(startTime)).toList();
    }

    if (endTime != null) {
      filtered = filtered.where((d) => d.recordTime.isBefore(endTime)).toList();
    }

    // 按类型统计
    final typeCounts = <HealthDataType, int>{};
    for (final item in filtered) {
      typeCounts[item.type] = (typeCounts[item.type] ?? 0) + 1;
    }

    return ExportStats(
      totalRecords: filtered.length,
      typeCounts: typeCounts,
      earliestRecord: filtered.isEmpty
          ? null
          : filtered.reduce((a, b) => a.recordTime.isBefore(b.recordTime) ? a : b).recordTime,
      latestRecord: filtered.isEmpty
          ? null
          : filtered.reduce((a, b) => a.recordTime.isAfter(b.recordTime) ? a : b).recordTime,
    );
  }
}

/// 导出结果
class ExportResult {
  final bool success;
  final String? content;
  final String? fileName;
  final int? recordCount;
  final String? errorMessage;
  final bool isBinary;

  ExportResult({
    required this.success,
    this.content,
    this.fileName,
    this.recordCount,
    this.errorMessage,
    this.isBinary = false,
  });
}

/// 导出统计信息
class ExportStats {
  final int totalRecords;
  final Map<HealthDataType, int> typeCounts;
  final DateTime? earliestRecord;
  final DateTime? latestRecord;

  ExportStats({
    required this.totalRecords,
    required this.typeCounts,
    this.earliestRecord,
    this.latestRecord,
  });
}
