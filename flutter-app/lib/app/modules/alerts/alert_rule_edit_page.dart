import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/app/modules/alerts/health_alert_controller.dart';
import 'package:health_center_app/core/models/health_alert.dart';

/// 预警规则编辑页面
class AlertRuleEditPage extends StatefulWidget {
  const AlertRuleEditPage({super.key});

  @override
  State<AlertRuleEditPage> createState() => _AlertRuleEditPageState();
}

class _AlertRuleEditPageState extends State<AlertRuleEditPage> {
  final HealthAlertController _controller = Get.find<HealthAlertController>();

  // 表单Key
  final _formKey = GlobalKey<FormState>();

  // 编辑模式
  bool get isEditMode => Get.arguments['mode'] == 'edit';
  HealthAlertRule? get existingRule => Get.arguments['rule'] as HealthAlertRule?;

  // 表单数据
  late TextEditingController _nameController;
  late TextEditingController _minThresholdController;
  late TextEditingController _maxThresholdController;

  AlertType _selectedType = AlertType.bloodPressure;
  String? _selectedMemberId;
  AlertLevel _selectedLevel = AlertLevel.warning;
  bool _isEnabled = true;

  @override
  void initState() {
    super.initState();

    // 初始化控制器
    _nameController = TextEditingController();
    _minThresholdController = TextEditingController();
    _maxThresholdController = TextEditingController();

    // 如果是编辑模式，填充现有数据
    if (isEditMode && existingRule != null) {
      final rule = existingRule!;
      _nameController.text = rule.name;
      _selectedType = rule.alertType;
      _selectedMemberId = rule.memberId;
      _selectedLevel = rule.alertLevel;
      _isEnabled = rule.isEnabled;

      if (rule.minThreshold != null) {
        _minThresholdController.text = rule.minThreshold.toString();
      }
      if (rule.maxThreshold != null) {
        _maxThresholdController.text = rule.maxThreshold.toString();
      }
    } else {
      // 新建模式，设置默认值
      _nameController.text = _getDefaultRuleName();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _minThresholdController.dispose();
    _maxThresholdController.dispose();
    super.dispose();
  }

  String _getDefaultRuleName() {
    switch (_selectedType) {
      case AlertType.bloodPressure:
        return '血压预警';
      case AlertType.heartRate:
        return '心率预警';
      case AlertType.bloodSugar:
        return '血糖预警';
      case AlertType.temperature:
        return '体温预警';
      case AlertType.weight:
        return '体重预警';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(isEditMode ? '编辑预警规则' : '添加预警规则'),
        elevation: 0,
        backgroundColor: const Color(0xFFF44336),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 基本信息
              _buildSectionTitle('基本信息'),
              SizedBox(height: 12.h),
              _buildNameField(),
              SizedBox(height: 16.h),
              _buildTypeSelector(),
              SizedBox(height: 16.h),
              _buildMemberSelector(),
              SizedBox(height: 24.h),

              // 阈值设置
              _buildSectionTitle('阈值设置'),
              SizedBox(height: 12.h),
              _buildThresholdHint(),
              SizedBox(height: 16.h),
              _buildMinThresholdField(),
              SizedBox(height: 16.h),
              _buildMaxThresholdField(),
              SizedBox(height: 24.h),

              // 预警级别
              _buildSectionTitle('预警级别'),
              SizedBox(height: 12.h),
              _buildAlertLevelSelector(),
              SizedBox(height: 24.h),

              // 其他选项
              _buildSectionTitle('其他选项'),
              SizedBox(height: 12.h),
              _buildEnabledSwitch(),
              SizedBox(height: 32.h),

              // 保存按钮
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// 章节标题
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.bold,
        color: Colors.grey[800],
      ),
    );
  }

  /// 规则名称输入
  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: '规则名称',
        hintText: '例如：血压过高预警',
        prefixIcon: const Icon(Icons.label_outline),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '请输入规则名称';
        }
        return null;
      },
    );
  }

  /// 类型选择器
  Widget _buildTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          ...AlertType.values.map((type) {
            return RadioListTile<AlertType>(
              title: Row(
                children: [
                  Icon(
                    _getAlertTypeIcon(type),
                    size: 20.sp,
                    color: _getAlertTypeColor(type),
                  ),
                  SizedBox(width: 8.w),
                  Text(type.label),
                ],
              ),
              subtitle: Text('单位：${_getUnitForType(type)}'),
              value: type,
              groupValue: _selectedType,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                    // 更新默认名称
                    if (!isEditMode || _nameController.text.isEmpty) {
                      _nameController.text = _getDefaultRuleName();
                    }
                  });
                }
              },
              activeColor: const Color(0xFFF44336),
              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
            );
          }),
        ],
      ),
    );
  }

  /// 成员选择器
  Widget _buildMemberSelector() {
    return DropdownButtonFormField<String?>(
      value: _selectedMemberId,
      decoration: InputDecoration(
        labelText: '适用成员',
        prefixIcon: const Icon(Icons.people_outline),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      items: [
        const DropdownMenuItem(
          value: null,
          child: Text('全部成员'),
        ),
        ..._controller.members.map((member) {
          return DropdownMenuItem(
            value: member.id,
            child: Text('${member.name} (${member.relation.label})'),
          );
        }),
      ],
      onChanged: (value) {
        setState(() {
          _selectedMemberId = value;
        });
      },
    );
  }

  /// 阈值提示
  Widget _buildThresholdHint() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16.sp, color: Colors.blue.shade700),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              '至少设置一个阈值，当数值低于最小值或高于最大值时触发预警',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.blue.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 最小阈值输入
  Widget _buildMinThresholdField() {
    return TextFormField(
      controller: _minThresholdController,
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: '最小阈值',
        hintText: '低于此值时触发预警',
        prefixIcon: const Icon(Icons.arrow_downward),
        suffixText: _getUnitForType(_selectedType),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) {
        // 如果最大值也没有，则最小值必填
        if (_maxThresholdController.text.trim().isEmpty) {
          if (value == null || value.trim().isEmpty) {
            return '请至少设置一个阈值';
          }
          final numValue = double.tryParse(value);
          if (numValue == null) {
            return '请输入有效的数值';
          }
        }
        return null;
      },
    );
  }

  /// 最大阈值输入
  Widget _buildMaxThresholdField() {
    return TextFormField(
      controller: _maxThresholdController,
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: '最大阈值',
        hintText: '高于此值时触发预警',
        prefixIcon: const Icon(Icons.arrow_upward),
        suffixText: _getUnitForType(_selectedType),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) {
        // 如果最小值也没有，则最大值必填
        if (_minThresholdController.text.trim().isEmpty) {
          if (value == null || value.trim().isEmpty) {
            return '请至少设置一个阈值';
          }
          final numValue = double.tryParse(value);
          if (numValue == null) {
            return '请输入有效的数值';
          }
        }
        return null;
      },
    );
  }

  /// 预警级别选择器
  Widget _buildAlertLevelSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: AlertLevel.values.map((level) {
          return RadioListTile<AlertLevel>(
            title: Row(
              children: [
                Icon(
                  _getLevelIcon(level),
                  size: 20.sp,
                  color: level.color,
                ),
                SizedBox(width: 8.w),
                Text(level.label),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: level.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    _getLevelDescription(level),
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: level.color,
                    ),
                  ),
                ),
              ],
            ),
            value: level,
            groupValue: _selectedLevel,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedLevel = value;
                });
              }
            },
            activeColor: const Color(0xFFF44336),
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
          );
        }).toList(),
      ),
    );
  }

  /// 启用开关
  Widget _buildEnabledSwitch() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(
            _isEnabled ? Icons.notifications_active : Icons.notifications_off,
            color: _isEnabled ? const Color(0xFFF44336) : Colors.grey,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '启用此规则',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _isEnabled ? '规则已启用，数据异常时会触发预警' : '规则已禁用',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isEnabled,
            onChanged: (value) {
              setState(() {
                _isEnabled = value;
              });
            },
            activeColor: const Color(0xFFF44336),
          ),
        ],
      ),
    );
  }

  /// 保存按钮
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saveRule,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF44336),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
        child: Text(
          isEditMode ? '保存修改' : '添加规则',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// 保存规则
  void _saveRule() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 解析阈值
    final minThreshold = _minThresholdController.text.trim().isEmpty
        ? null
        : double.tryParse(_minThresholdController.text);
    final maxThreshold = _maxThresholdController.text.trim().isEmpty
        ? null
        : double.tryParse(_maxThresholdController.text);

    if (minThreshold == null && maxThreshold == null) {
      Get.snackbar(
        '提示',
        '请至少设置一个阈值',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange.shade100,
      );
      return;
    }

    // 创建或更新规则
    final rule = HealthAlertRule(
      id: isEditMode ? existingRule!.id : DateTime.now().millisecondsSinceEpoch.toString(),
      memberId: _selectedMemberId,
      alertType: _selectedType,
      name: _nameController.text.trim(),
      minThreshold: minThreshold,
      maxThreshold: maxThreshold,
      alertLevel: _selectedLevel,
      isEnabled: _isEnabled,
      notificationMethods: const ['push'],
      createTime: isEditMode ? existingRule!.createTime : DateTime.now(),
      updateTime: isEditMode ? DateTime.now() : null,
    );

    // 保存
    final Future<bool> saveFuture = isEditMode
        ? _controller.updateAlertRule(rule)
        : _controller.addAlertRule(rule);

    saveFuture.then((success) {
      if (success) {
        Get.back();
      }
    });
  }

  /// 获取类型对应的单位
  String _getUnitForType(AlertType type) {
    switch (type) {
      case AlertType.bloodPressure:
        return 'mmHg';
      case AlertType.heartRate:
        return 'bpm';
      case AlertType.bloodSugar:
        return 'mmol/L';
      case AlertType.temperature:
        return '°C';
      case AlertType.weight:
        return 'kg';
    }
  }

  /// 获取预警类型图标
  IconData _getAlertTypeIcon(AlertType type) {
    switch (type) {
      case AlertType.bloodPressure:
        return Icons.favorite;
      case AlertType.heartRate:
        return Icons.monitor_heart;
      case AlertType.bloodSugar:
        return Icons.water_drop;
      case AlertType.temperature:
        return Icons.thermostat;
      case AlertType.weight:
        return Icons.monitor_weight;
    }
  }

  /// 获取预警类型颜色
  Color _getAlertTypeColor(AlertType type) {
    switch (type) {
      case AlertType.bloodPressure:
        return const Color(0xFF4CAF50);
      case AlertType.heartRate:
        return const Color(0xFFF44336);
      case AlertType.bloodSugar:
        return const Color(0xFFFF9800);
      case AlertType.temperature:
        return const Color(0xFF2196F3);
      case AlertType.weight:
        return const Color(0xFF9C27B0);
    }
  }

  /// 获取级别图标
  IconData _getLevelIcon(AlertLevel level) {
    switch (level) {
      case AlertLevel.info:
        return Icons.info_outline;
      case AlertLevel.warning:
        return Icons.warning_amber;
      case AlertLevel.danger:
        return Icons.error;
    }
  }

  /// 获取级别描述
  String _getLevelDescription(AlertLevel level) {
    switch (level) {
      case AlertLevel.info:
        return '一般提醒';
      case AlertLevel.warning:
        return '需要关注';
      case AlertLevel.danger:
        return '紧急处理';
    }
  }
}
