import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/app/modules/content/health_content_controller.dart';
import 'package:health_center_app/core/models/health_content.dart';

/// 健康文章详情页面
class ArticleDetailPage extends StatelessWidget {
  const ArticleDetailPage({super.key});

  HealthArticle get article => Get.arguments as HealthArticle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('文章详情'),
        elevation: 0,
        backgroundColor: article.category.color,
        foregroundColor: Colors.white,
        actions: [
          // 分享按钮
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareArticle(),
          ),
        ],
      ),
      body: GetBuilder<HealthContentController>(
        init: HealthContentController(),
        builder: (controller) {
          return CustomScrollView(
            slivers: [
              // 头部信息
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: article.category.color.withOpacity(0.1),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(20.r)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 分类标签
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: article.category.color,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(article.category.icon, size: 16.sp, color: Colors.white),
                            SizedBox(width: 4.w),
                            Text(
                              article.category.label,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // 标题
                      Text(
                        article.title,
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 12.h),

                      // 摘要
                      Text(
                        article.summary,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // 作者信息
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18.r,
                            backgroundColor: article.category.color.withOpacity(0.2),
                            child: Icon(
                              Icons.person,
                              size: 18.sp,
                              color: article.category.color,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                article.author,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _formatDate(article.publishTime),
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // 收藏按钮
                          Obx(() {
                            final isBookmarked = controller.isBookmarked(article.id);
                            return IconButton(
                              icon: Icon(
                                isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                                color: isBookmarked ? Colors.amber : Colors.grey[400],
                              ),
                              onPressed: () => controller.toggleBookmark(article.id),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 文章内容
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 统计信息
                      Row(
                        children: [
                          _buildStatItem(Icons.access_time, '${article.readTime}分钟'),
                          SizedBox(width: 24.w),
                          _buildStatItem(Icons.visibility, '${article.viewCount}'),
                        ],
                      ),
                      SizedBox(height: 20.h),

                      // 标签
                      if (article.tags.isNotEmpty) ...[
                        Wrap(
                          spacing: 8.w,
                          runSpacing: 8.h,
                          children: article.tags.map((tag) {
                            return Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Text(
                                '#${tag.label}',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: Colors.grey[700],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        SizedBox(height: 20.h),
                      ],

                      // 内容
                      _buildContent(article.content),
                    ],
                  ),
                ),
              ),

              // 底部操作栏
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Get.back(),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('返回列表'),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _shareArticle(),
                          icon: const Icon(Icons.share),
                          label: const Text('分享'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: article.category.color,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 统计项
  Widget _buildStatItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16.sp, color: Colors.grey[400]),
        SizedBox(width: 4.w),
        Text(
          text,
          style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
        ),
      ],
    );
  }

  /// 构建内容
  Widget _buildContent(String content) {
    // 简单的Markdown渲染
    final lines = content.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      if (line.trim().isEmpty) {
        widgets.add(SizedBox(height: 12.h));
        continue;
      }

      // 标题
      if (line.startsWith('# ')) {
        widgets.add(
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Text(
              line.substring(2),
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
        );
      } else if (line.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: EdgeInsets.symmetric(vertical: 10.h),
            child: Text(
              line.substring(3),
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
        );
      } else if (line.startsWith('### ')) {
        widgets.add(
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Text(
              line.substring(4),
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
        );
      }
      // 列表项
      else if (line.trim().startsWith('- ') || line.trim().startsWith('• ')) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(left: 16.w, bottom: 8.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(fontSize: 14.sp, color: Colors.grey[800])),
                Expanded(
                  child: Text(
                    line.trim().substring(2),
                    style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (line.trim().startsWith(RegExp(r'\d+\.'))) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(left: 16.w, bottom: 8.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${line.trim().split('.')[0]}. ',
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey[800]),
                ),
                Expanded(
                  child: Text(
                    line.trim().substring(line.trim().indexOf('.') + 1),
                    style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      // 普通段落
      else {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Text(
              line,
              style: TextStyle(
                fontSize: 15.sp,
                height: 1.6,
                color: Colors.grey[700],
              ),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '今天';
    } else if (diff.inDays == 1) {
      return '昨天';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${date.month}月${date.day}日';
    }
  }

  /// 分享文章
  void _shareArticle() {
    Get.snackbar(
      '分享',
      '分享功能开发中...',
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}
