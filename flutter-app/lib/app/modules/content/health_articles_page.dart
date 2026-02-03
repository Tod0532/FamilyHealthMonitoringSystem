import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:health_center_app/app/modules/content/health_content_controller.dart';
import 'package:health_center_app/core/models/health_content.dart';

/// 健康内容文章列表页面
class HealthArticlesPage extends GetView<HealthContentController> {
  const HealthArticlesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('健康知识'),
        elevation: 0,
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        actions: [
          // 搜索按钮
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
          ),
          // 收藏按钮
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            onPressed: () => _showBookmarks(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 分类筛选栏
          _buildCategoryFilter(),

          // 推荐区域
          _buildRecommendedSection(),

          // 文章列表
          Expanded(
            child: Obx(() {
              final articles = controller.filteredArticles;
              if (articles.isEmpty) {
                return _buildEmptyState();
              }
              return ListView.separated(
                padding: EdgeInsets.all(16.w),
                itemCount: articles.length,
                separatorBuilder: (_, __) => SizedBox(height: 12.h),
                itemBuilder: (context, index) {
                  return _buildArticleCard(context, articles[index]);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  /// 分类筛选栏
  Widget _buildCategoryFilter() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Obx(() {
          final selected = controller.selectedCategory.value;
          return Row(
            children: [
              _buildCategoryChip(null, '全部', selected == null),
              SizedBox(width: 8.w),
              ...ContentCategory.values.map((category) {
                final isSelected = selected == category;
                final count = controller.getCategoryCount(category);
                return Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: _buildCategoryChip(
                    category,
                    '${category.label}($count)',
                    isSelected,
                  ),
                );
              }),
            ],
          );
        }),
      ),
    );
  }

  /// 分类芯片
  Widget _buildCategoryChip(ContentCategory? category, String label, bool isSelected) {
    final color = category?.color ?? const Color(0xFF4CAF50);
    final icon = category?.icon;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16.sp, color: isSelected ? Colors.white : color),
            SizedBox(width: 4.w),
          ],
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        controller.filterByCategory(selected ? category : null);
      },
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      labelStyle: TextStyle(
        fontSize: 12.sp,
        color: isSelected ? color : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.grey[100],
      side: BorderSide(
        color: isSelected ? color : Colors.transparent,
      ),
    );
  }

  /// 推荐区域
  Widget _buildRecommendedSection() {
    return Obx(() {
      final recommended = controller.recommendedArticles;
      if (recommended.isEmpty) {
        return const SizedBox.shrink();
      }

      return Container(
        color: Colors.green.shade50,
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.recommend, color: Colors.green.shade700, size: 20.sp),
                SizedBox(width: 8.w),
                Text(
                  '为你推荐',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: controller.refreshRecommendations,
                  child: Text('换一批', style: TextStyle(fontSize: 12.sp)),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            SizedBox(
              height: 180.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recommended.length,
                separatorBuilder: (_, __) => SizedBox(width: 12.w),
                itemBuilder: (context, index) {
                  return _buildRecommendedCard(recommended[index]);
                },
              ),
            ),
          ],
        ),
      );
    });
  }

  /// 推荐卡片
  Widget _buildRecommendedCard(HealthArticle article) {
    return GestureDetector(
      onTap: () => Get.toNamed('/content/article-detail', arguments: article),
      child: Container(
        width: 280.w,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面图
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
                  gradient: LinearGradient(
                    colors: [article.category.color.withOpacity(0.3), article.category.color.withOpacity(0.1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Icon(
                    article.category.icon,
                    size: 48.sp,
                    color: article.category.color.withOpacity(0.6),
                  ),
                ),
              ),
            ),
            // 内容
            Padding(
              padding: EdgeInsets.all(12.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12.sp, color: Colors.grey[400]),
                      SizedBox(width: 4.w),
                      Text(
                        '${article.readTime}分钟',
                        style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
                      ),
                      SizedBox(width: 12.w),
                      Icon(Icons.visibility, size: 12.sp, color: Colors.grey[400]),
                      SizedBox(width: 4.w),
                      Text(
                        '${article.viewCount}',
                        style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 文章卡片
  Widget _buildArticleCard(BuildContext context, HealthArticle article) {
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
              width: 100.w,
              height: 100.w,
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
                  size: 40.sp,
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
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8.h),

                    // 摘要
                    Text(
                      article.summary,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8.h),

                    // 底部信息
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
                        const Spacer(),
                        Obx(() {
                          final isBookmarked = controller.isBookmarked(article.id);
                          return GestureDetector(
                            onTap: () => controller.toggleBookmark(article.id),
                            child: Icon(
                              isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                              size: 20.sp,
                              color: isBookmarked ? Colors.amber : Colors.grey[400],
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 64.sp, color: Colors.grey[300]),
          SizedBox(height: 16.h),
          Text(
            '暂无相关文章',
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// 搜索对话框
  void _showSearchDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('搜索文章'),
        content: TextField(
          autofocus: true,
          decoration: InputDecoration(
            hintText: '输入关键词...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
          onSubmitted: (value) {
            controller.search(value);
            Get.back();
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.clearSearch();
              Get.back();
            },
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _showSearchDialog();
            },
            child: const Text('搜索'),
          ),
        ],
      ),
    );
  }

  /// 显示收藏列表
  void _showBookmarks(BuildContext context) {
    Get.toNamed('/content/bookmarks');
  }
}
