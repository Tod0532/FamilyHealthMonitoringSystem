import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/app/modules/content/health_content_controller.dart';
import 'package:health_center_app/core/models/health_content.dart';

/// 收藏列表页面
class BookmarksPage extends GetView<HealthContentController> {
  const BookmarksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('我的收藏'),
        elevation: 0,
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: Obx(() {
        final bookmarks = controller.bookmarkedArticles;
        if (bookmarks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bookmark_border, size: 64.sp, color: Colors.grey[300]),
                SizedBox(height: 16.h),
                Text(
                  '还没有收藏的文章',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  '浏览文章时点击收藏按钮添加',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.all(16.w),
          itemCount: bookmarks.length,
          separatorBuilder: (_, __) => SizedBox(height: 12.h),
          itemBuilder: (context, index) {
            return _buildBookmarkCard(context, bookmarks[index]);
          },
        );
      }),
    );
  }

  /// 收藏卡片
  Widget _buildBookmarkCard(BuildContext context, HealthArticle article) {
    return GestureDetector(
      onTap: () => Get.toNamed('/content/article-detail', arguments: article),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面图
            Container(
              width: 80.w,
              height: 80.w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.r),
                gradient: LinearGradient(
                  colors: [article.category.color.withOpacity(0.3), article.category.color.withOpacity(0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Icon(
                  article.category.icon,
                  size: 32.sp,
                  color: article.category.color.withOpacity(0.6),
                ),
              ),
            ),
            SizedBox(width: 12.w),

            // 内容
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题
                    Text(
                      article.title,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8.h),

                    // 分类和时间
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: article.category.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            article.category.label,
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: article.category.color,
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Icon(Icons.access_time, size: 12.sp, color: Colors.grey[400]),
                        SizedBox(width: 2.w),
                        Text(
                          '${article.readTime}分钟',
                          style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 取消收藏按钮
            Padding(
              padding: EdgeInsets.all(12.w),
              child: GestureDetector(
                onTap: () => _confirmRemoveBookmark(article.id),
                child: Icon(
                  Icons.bookmark,
                  size: 24.sp,
                  color: Colors.amber,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 确认取消收藏
  void _confirmRemoveBookmark(String articleId) {
    Get.dialog(
      AlertDialog(
        title: const Text('取消收藏'),
        content: const Text('确定要取消收藏这篇文章吗？'),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              controller.toggleBookmark(articleId);
              Get.back();
              Get.snackbar(
                '已取消',
                '文章已从收藏中移除',
                snackPosition: SnackPosition.BOTTOM,
              );
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
