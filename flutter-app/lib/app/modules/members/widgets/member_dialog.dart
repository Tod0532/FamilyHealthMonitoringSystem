import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/core/models/family_member.dart';

/// 添加/编辑成员弹窗
class MemberDialog extends StatefulWidget {
  final FamilyMember? member;
  final Future<bool> Function(FamilyMember) onSave;

  const MemberDialog({
    super.key,
    this.member,
    required this.onSave,
  });

  @override
  State<MemberDialog> createState() => _MemberDialogState();
}

class _MemberDialogState extends State<MemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  MemberRelation _selectedRelation = MemberRelation.other;
  MemberRole _selectedRole = MemberRole.member;
  int _selectedGender = 0;
  DateTime? _selectedBirthday;

  @override
  void initState() {
    super.initState();
    if (widget.member != null) {
      _nameController.text = widget.member!.name;
      _selectedRelation = widget.member!.relation;
      _selectedRole = widget.member!.role;
      _selectedGender = widget.member!.gender;
      _selectedBirthday = widget.member!.birthday;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.member != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        width: 320.w,
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEdit ? '编辑成员' : '添加成员',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () => Get.back(),
                  child: const Icon(Icons.close),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            // 表单
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // 姓名输入
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: '姓名',
                      hintText: '请输入姓名',
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
                        return '请输入姓名';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 12.h),

                  // 关系选择
                  DropdownButtonFormField<MemberRelation>(
                    value: _selectedRelation,
                    decoration: InputDecoration(
                      labelText: '关系',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 12.h,
                      ),
                    ),
                    items: MemberRelation.values.map((relation) {
                      return DropdownMenuItem(
                        value: relation,
                        child: Text(relation.label),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedRelation = value!;
                      });
                    },
                  ),
                  SizedBox(height: 12.h),

                  // 角色选择
                  DropdownButtonFormField<MemberRole>(
                    value: _selectedRole,
                    decoration: InputDecoration(
                      labelText: '角色',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 12.h,
                      ),
                    ),
                    items: MemberRole.values.map((role) {
                      return DropdownMenuItem(
                        value: role,
                        child: Row(
                          children: [
                            Icon(role.icon, size: 16, color: const Color(0xFF4CAF50)),
                            SizedBox(width: 8.w),
                            Text(role.label),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedRole = value!;
                      });
                    },
                  ),
                  SizedBox(height: 12.h),

                  // 性别选择
                  Row(
                    children: [
                      Text(
                        '性别',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      ...List.generate(2, (index) {
                        final labels = ['男', '女'];
                        final values = [1, 2];
                        return Row(
                          children: [
                            Radio<int>(
                              value: values[index],
                              groupValue: _selectedGender,
                              onChanged: (value) {
                                setState(() {
                                  _selectedGender = value!;
                                });
                              },
                            ),
                            Text(labels[index]),
                            SizedBox(width: 16.w),
                          ],
                        );
                      }),
                    ],
                  ),
                  SizedBox(height: 12.h),

                  // 出生日期
                  InkWell(
                    onTap: _selectBirthday,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: '出生日期',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 12.h,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedBirthday != null
                                ? '${_selectedBirthday!.year}-${_selectedBirthday!.month.toString().padLeft(2, '0')}-${_selectedBirthday!.day.toString().padLeft(2, '0')}'
                                : '请选择日期',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: _selectedBirthday != null
                                  ? Colors.black
                                  : Colors.grey,
                            ),
                          ),
                          const Icon(Icons.calendar_today),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // 确认按钮
            SizedBox(
              width: double.infinity,
              height: 44.h,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 选择出生日期
  Future<void> _selectBirthday() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedBirthday = picked;
      });
    }
  }

  /// 提交表单
  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final member = FamilyMember(
      id: widget.member?.id ?? '',
      name: _nameController.text.trim(),
      relation: _selectedRelation,
      role: _selectedRole,
      gender: _selectedGender,
      birthday: _selectedBirthday,
      createTime: widget.member?.createTime ?? DateTime.now(),
    );

    widget.onSave(member).then((success) {
      if (success) {
        Get.back();
      }
    });
  }
}
