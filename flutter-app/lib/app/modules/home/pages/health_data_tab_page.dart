import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 健康数据Tab页（占位）
class HealthDataTabPage extends StatelessWidget {
  const HealthDataTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 80.w,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16.h),
            Text(
              '健康数据中心',
              style: TextStyle(
                fontSize: 18.sp,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              '即将上线',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
