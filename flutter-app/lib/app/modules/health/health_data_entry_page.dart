import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/app/modules/health/health_data_controller.dart';
import 'package:health_center_app/core/models/health_data.dart';
import 'package:health_center_app/core/models/family_member.dart';
import 'package:health_center_app/core/widgets/ocr_button.dart';
import 'package:health_center_app/core/ocr/models/ocr_result.dart';

/// 健康数据录入页面
class HealthDataEntryPage extends StatefulWidget {
  const HealthDataEntryPage({super.key});

  @override
  State<HealthDataEntryPage> createState() => _HealthDataEntryPageState();
}

class _HealthDataEntryPageState extends State<HealthDataEntryPage> {
  late final HealthDataController _controller;
  late String _mode;
  HealthData? _editData;

  // 表单key
  final _formKey = GlobalKey<FormState>();

  // 选中的数据类型
  final _selectedType = HealthDataType.bloodPressure.obs;

  // 选中的成员
  final Rx<FamilyMember?> _selectedMember = Rx<FamilyMember?>(null);

  // 数值输入控制器
  final _value1Controller = TextEditingController();
  final _value2Controller = TextEditingController();
  final _notesController = TextEditingController();

  // 记录时间
  final _recordTime = DateTime.now().obs;

  // 血压相关
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();

  /// 有一次 OCR 结果可信度偏低，等用户核对确认
  ///
  /// 置位期间**不允许保存** —— 否则"提示"就只是装饰：错值照样被存进去。
  bool _reviewPending = false;

  /// 提示条上的原因文案（来自 OcrQuality.reviewReason）
  String _reviewNote = '';

  @override
  void initState() {
    super.initState();
    _controller = Get.find<HealthDataController>();

    // 获取传入的参数
    final args = Get.arguments as Map<String, dynamic>?;
    _mode = args?['mode'] ?? 'add';
    _editData = args?['data'] as HealthData?;

    // 初始化数据
    if (_mode == 'edit' && _editData != null) {
      _initEditData();
    } else {
      // 先刷新成员列表，再选中第一个成员
      _refreshAndSelectMember();
    }
  }

  /// 刷新成员列表并选中第一个
  Future<void> _refreshAndSelectMember() async {
    await _controller.refreshMembers();
    if (_controller.members.isNotEmpty) {
      _selectedMember.value = _controller.members.first;
    }
  }

  /// 初始化编辑数据
  void _initEditData() {
    _selectedType.value = _editData!.type;
    _selectedMember.value = _controller.getMemberById(_editData!.memberId);
    _recordTime.value = _editData!.recordTime;
    _notesController.text = _editData!.notes ?? '';

    switch (_editData!.type) {
      case HealthDataType.bloodPressure:
        _systolicController.text = _editData!.value1.toInt().toString();
        _diastolicController.text = _editData!.value2?.toInt().toString() ?? '';
        break;
      default:
        _value1Controller.text = _editData!.value1.toString();
        break;
    }
  }

  @override
  void dispose() {
    _value1Controller.dispose();
    _value2Controller.dispose();
    _notesController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: () {
            // 长按标题进入 OCR 测试页面（开发调试用）
            Get.toNamed('/debug/ocr-test');
          },
          child: Text(_mode == 'edit' ? '编辑记录' : '添加记录'),
        ),
        elevation: 0,
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 选择成员
              _buildSectionTitle('选择成员'),
              _buildMemberSelector(),
              SizedBox(height: 16.h),

              // 选择数据类型
              _buildSectionTitle('数据类型'),
              _buildTypeSelector(),
              SizedBox(height: 16.h),

              // 数据输入
              _buildSectionTitle('数据录入'),
              if (_reviewPending) _buildReviewBanner(),
              Obx(() => _buildDataInput(_selectedType.value)),
              SizedBox(height: 16.h),

              // 记录时间
              _buildSectionTitle('记录时间'),
              _buildDateTimePicker(),
              SizedBox(height: 16.h),

              // 备注
              _buildSectionTitle('备注（可选）'),
              _buildNotesField(),
              SizedBox(height: 24.h),

              // 提交按钮
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// 区块标题
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14.sp,
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// 成员选择器
  Widget _buildMemberSelector() {
    return Obx(() {
      if (_controller.members.isEmpty) {
        return Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey[600], size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                '暂无家庭成员，请先添加',
                style: TextStyle(color: Colors.grey[600], fontSize: 14.sp),
              ),
            ],
          ),
        );
      }

      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<FamilyMember>(
            isExpanded: true,
            value: _selectedMember.value,
            hint: Text('请选择成员', style: TextStyle(fontSize: 14.sp)),
            items: _controller.members.map((member) {
              return DropdownMenuItem<FamilyMember>(
                value: member,
                child: Row(
                  children: [
                    _buildMemberAvatar(member),
                    SizedBox(width: 8.w),
                    Text(
                      member.name,
                      style: TextStyle(fontSize: 14.sp),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      '(${member.relation.label})',
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              _selectedMember.value = value;
            },
          ),
        ),
      );
    });
  }

  /// 成员头像
  Widget _buildMemberAvatar(FamilyMember member) {
    Color avatarColor;
    switch (member.gender) {
      case 1:
        avatarColor = const Color(0xFF64B5F6);
        break;
      case 2:
        avatarColor = const Color(0xFFF06292);
        break;
      default:
        avatarColor = const Color(0xFF4CAF50);
    }

    return Container(
      width: 32.w,
      height: 32.w,
      decoration: BoxDecoration(
        color: avatarColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Center(
        child: Text(
          member.name.isNotEmpty ? member.name[0] : '?',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: avatarColor,
          ),
        ),
      ),
    );
  }

  /// 数据类型选择器
  Widget _buildTypeSelector() {
    return Container(
      height: 100.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: HealthDataType.values.length,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final type = HealthDataType.values[index];
          return Obx(() {
            final isSelected = _selectedType.value == type;
            return InkWell(
              onTap: () {
                _selectedType.value = type;
                // 清空输入
                _value1Controller.clear();
                _value2Controller.clear();
                _systolicController.clear();
                _diastolicController.clear();
              },
              child: Container(
                width: 80.w,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF4CAF50) : Colors.white,
                  border: Border.all(
                    color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[300]!,
                  ),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      type.icon,
                      color: isSelected ? Colors.white : Colors.grey[600],
                      size: 24.sp,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      type.label,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: isSelected ? Colors.white : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            );
          });
        },
      ),
    );
  }

  /// 数据输入区域
  Widget _buildDataInput(HealthDataType type) {
    switch (type) {
      case HealthDataType.bloodPressure:
        return _buildBloodPressureInput();
      case HealthDataType.heartRate:
        return _buildHeartRateInput();
      case HealthDataType.bloodSugar:
        return _buildSingleValueInput('血糖', 'mmol/L', Icons.water_drop, 1.0, 30.0);
      case HealthDataType.temperature:
        return _buildSingleValueInput('体温', '℃', Icons.thermostat, 35.0, 42.0);
      case HealthDataType.weight:
        return _buildSingleValueInput('体重', 'kg', Icons.monitor_weight, 20.0, 200.0);
      case HealthDataType.height:
        return _buildSingleValueInput('身高', 'cm', Icons.height, 50, 250);
      case HealthDataType.steps:
        return _buildSingleValueInput('步数', '步', Icons.directions_walk, 0, 100000);
      case HealthDataType.sleep:
        return _buildSingleValueInput('睡眠时长', '小时', Icons.bedtime, 0, 24);
    }
  }

  /// 血压输入
  Widget _buildBloodPressureInput() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildInputCard(
                label: '收缩压',
                unit: 'mmHg',
                icon: Icons.arrow_upward,
                controller: _systolicController,
                hint: '高压',
                min: 60,
                max: 250,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildInputCard(
                label: '舒张压',
                unit: 'mmHg',
                icon: Icons.arrow_downward,
                controller: _diastolicController,
                hint: '低压',
                min: 30,
                max: 150,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        // OCR识别按钮
        OcrButton(
          buttonText: '📷 拍照识别血压',
          onResult: _handleBloodPressureOcrResult,
        ),
      ],
    );
  }

  /// 单值输入
  Widget _buildSingleValueInput(
    String label,
    String unit,
    IconData icon,
    double min,
    double max,
  ) {
    return _buildInputCard(
      label: label,
      unit: unit,
      icon: icon,
      controller: _value1Controller,
      hint: "请输入$label",
      min: min,
      max: max,
    );
  }

  /// 心率输入（带OCR功能）
  Widget _buildHeartRateInput() {
    return Column(
      children: [
        _buildSingleValueInput('心率', 'bpm', Icons.monitor_heart, 30, 200),
        SizedBox(height: 12.h),
        // OCR识别按钮
        OcrButton(
          buttonText: '📷 拍照识别心率',
          onResult: _handleHeartRateOcrResult,
        ),
      ],
    );
  }

  /// 输入卡片
  Widget _buildInputCard({
    required String label,
    required String unit,
    required IconData icon,
    required TextEditingController controller,
    required String hint,
    required double min,
    required double max,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20.sp, color: const Color(0xFF4CAF50)),
              SizedBox(width: 8.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            // 用户自己改了数值 = 已经核对过，撤掉"请核对"提示
            onChanged: (_) => _clearReviewIfEdited(),
            decoration: InputDecoration(
              hintText: hint,
              suffixText: unit,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 12.h,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入$label';
              }
              final numValue = double.tryParse(value);
              if (numValue == null) {
                return '请输入有效的数值';
              }
              if (numValue < min || numValue > max) {
                return '请输入 ${min.toString()} - ${max.toString()} 之间的数值';
              }
              return null;
            },
          ),
          // 正常范围提示
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: Text(
              '正常范围: ${min.toString()} - ${max.toString()} $unit',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey[500],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 日期时间选择器
  Widget _buildDateTimePicker() {
    return InkWell(
      onTap: () => _selectDateTime(),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, color: const Color(0xFF4CAF50)),
            SizedBox(width: 12.w),
            Obx(() {
              return Text(
                _formatDateTime(_recordTime.value),
                style: TextStyle(fontSize: 14.sp),
              );
            }),
            const Spacer(),
            Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// 选择日期时间
  Future<void> _selectDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _recordTime.value,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
    );

    if (date != null && context.mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_recordTime.value),
      );

      if (time != null) {
        _recordTime.value = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
      }
    }
  }

  /// 备注输入
  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      maxLines: 3,
      decoration: InputDecoration(
        hintText: '添加备注信息...',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12.w,
          vertical: 12.h,
        ),
      ),
    );
  }

  /// 提交按钮
  Widget _buildSubmitButton() {
    return Obx(() {
      final isLoading = _controller.isSubmitting.value;
      return SizedBox(
        width: double.infinity,
        height: 48.h,
        child: ElevatedButton(
          onPressed: isLoading ? null : _submitForm,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  _mode == 'edit' ? '保存修改' : '保存记录',
                  style: TextStyle(fontSize: 16.sp),
                ),
        ),
      );
    });
  }

  /// 提交表单
  void _submitForm() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 低可信度的识别结果必须先人工核对，否则不给存 ——
    // 只提示不拦，等于把"看着合理"的错值直接写进健康档案
    if (_reviewPending) {
      Get.snackbar(
        '请先核对识别结果',
        '这张照片的识别可信度偏低，请对照血压计屏幕确认数值无误后再保存',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange.shade100,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    if (_selectedMember.value == null) {
      Get.snackbar(
        '提示',
        '请选择成员',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange.shade100,
      );
      return;
    }

    final type = _selectedType.value;
    late HealthData data;

    // 根据类型创建数据
    switch (type) {
      case HealthDataType.bloodPressure:
        final systolic = double.tryParse(_systolicController.text) ?? 0;
        final diastolic = double.tryParse(_diastolicController.text) ?? 0;
        data = HealthData.createBloodPressure(
          id: _mode == 'edit' ? _editData!.id : '',
          memberId: _selectedMember.value!.id,
          systolic: systolic,
          diastolic: diastolic,
          recordTime: _recordTime.value,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
        );
        break;

      case HealthDataType.heartRate:
        final rate = double.tryParse(_value1Controller.text) ?? 0;
        data = HealthData.createHeartRate(
          id: _mode == 'edit' ? _editData!.id : '',
          memberId: _selectedMember.value!.id,
          rate: rate,
          recordTime: _recordTime.value,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
        );
        break;

      case HealthDataType.bloodSugar:
        final sugar = double.tryParse(_value1Controller.text) ?? 0;
        data = HealthData.createBloodSugar(
          id: _mode == 'edit' ? _editData!.id : '',
          memberId: _selectedMember.value!.id,
          sugar: sugar,
          recordTime: _recordTime.value,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
        );
        break;

      case HealthDataType.temperature:
        final temp = double.tryParse(_value1Controller.text) ?? 0;
        data = HealthData.createTemperature(
          id: _mode == 'edit' ? _editData!.id : '',
          memberId: _selectedMember.value!.id,
          temp: temp,
          recordTime: _recordTime.value,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
        );
        break;

      default:
        final value = double.tryParse(_value1Controller.text) ?? 0;
        data = HealthData(
          id: _mode == 'edit' ? _editData!.id : '',
          memberId: _selectedMember.value!.id,
          type: type,
          value1: value,
          level: HealthDataLevel.normal,
          recordTime: _recordTime.value,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
          createTime: DateTime.now(),
        );
        break;
    }

    _saveData(data);
  }

  /// 处理血压OCR识别结果
  void _handleBloodPressureOcrResult(OcrResult result) {
    if (result.systolic != null) {
      _systolicController.text = result.systolic!.toInt().toString();
    }
    if (result.diastolic != null) {
      _diastolicController.text = result.diastolic!.toInt().toString();
    }
    // 如果同时识别到心率，也填充到输入框（方便后续切换类型）
    if (result.heartRate != null) {
      _value1Controller.text = result.heartRate!.toInt().toString();
    }
    _applyOcrQuality(result);
  }

  /// 处理心率OCR识别结果
  void _handleHeartRateOcrResult(OcrResult result) {
    if (result.heartRate != null) {
      _value1Controller.text = result.heartRate!.toInt().toString();
    }
    // 如果同时识别到血压，也填到输入框（方便后续切换类型）
    if (result.systolic != null) {
      _systolicController.text = result.systolic!.toInt().toString();
    }
    if (result.diastolic != null) {
      _diastolicController.text = result.diastolic!.toInt().toString();
    }
    _applyOcrQuality(result);
  }

  /// 识别可信度偏低时挂上"请核对"提示
  ///
  /// 为什么要这一步：血压计**读错**的时候给的是"看着很合理"的错值
  /// （真值 138/88 被读成 133/88），用户看不出来就直接存了 —— 这比识别失败更危险。
  /// 判据不是拍脑袋定的：见 `lib/core/ocr/models/ocr_quality.dart` 与标定脚本
  /// `tool/confidence_calibration.py`（60 张真实照片跑完整 81 组 TTA）。
  void _applyOcrQuality(OcrResult result) {
    if (!mounted) return;
    setState(() {
      _reviewPending = result.needsReview;
      _reviewNote = result.quality?.reviewReason ?? '';
    });
  }

  /// 用户手动改过数值 = 已经自己核对过了，撤掉提示（避免反复打扰）
  void _clearReviewIfEdited() {
    if (!_reviewPending) return;
    setState(() {
      _reviewPending = false;
      _reviewNote = '';
    });
  }

  /// "请核对"提示条
  Widget _buildReviewBanner() {
    const warn = Color(0xFFEF6C00);
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        border: Border.all(color: const Color(0xFFFFB74D)),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: warn, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                '识别结果请核对',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                  color: warn,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          if (_reviewNote.isNotEmpty)
            Text(
              _reviewNote,
              style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade800),
            ),
          SizedBox(height: 4.h),
          Text(
            '血压计读数识别错时，给出的往往也是"看起来很正常"的数字。'
            '请对照血压计屏幕确认后再保存。',
            style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _reviewPending = false;
                  _reviewNote = '';
                });
              },
              icon: Icon(Icons.check_circle_outline, size: 18.sp),
              label: Text('我已核对，数值正确', style: TextStyle(fontSize: 13.sp)),
              style: TextButton.styleFrom(foregroundColor: warn),
            ),
          ),
        ],
      ),
    );
  }

  /// 保存数据
  Future<void> _saveData(HealthData data) async {
    final success = _mode == 'edit'
        ? await _controller.updateHealthData(data)
        : await _controller.addHealthData(data);

    if (success) {
      Get.back();
    }
  }
}
