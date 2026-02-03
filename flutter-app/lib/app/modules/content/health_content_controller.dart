import 'package:get/get.dart';
import 'package:health_center_app/core/models/health_content.dart';
import 'package:health_center_app/app/modules/health/health_data_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 健康内容控制器
class HealthContentController extends GetxController {
  // 所有文章
  final allArticles = <HealthArticle>[].obs;

  // 推荐文章
  final recommendedArticles = <HealthArticle>[].obs;

  // 当前选中的分类
  final selectedCategory = Rxn<ContentCategory>();

  // 收藏的文章ID列表
  final bookmarkedArticleIds = <String>[].obs;

  // 搜索关键词
  final searchKeyword = ''.obs;

  // 加载状态
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadArticles();
    _loadBookmarks();
    _generateRecommendations();
  }

  /// 加载文章数据
  void _loadArticles() {
    isLoading.value = true;

    // 模拟文章数据
    allArticles.value = _getMockArticles();

    isLoading.value = false;
  }

  /// 加载收藏
  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarkList = prefs.getStringList('bookmarked_articles') ?? [];
    bookmarkedArticleIds.value = bookmarkList;
  }

  /// 保存收藏
  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('bookmarked_articles', bookmarkedArticleIds);
  }

  /// 生成推荐内容
  void _generateRecommendations() {
    if (!Get.isRegistered<HealthDataController>()) {
      // 如果没有健康数据控制器，返回热门文章
      recommendedArticles.value = allArticles.take(5).toList();
      return;
    }

    final healthController = Get.find<HealthDataController>();
    final recentData = healthController.healthDataList.take(10).toList();

    if (recentData.isEmpty) {
      recommendedArticles.value = allArticles.take(5).toList();
      return;
    }

    // 收集所有标签
    final userTags = <ContentTag>[];
    for (final data in recentData) {
      userTags.addAll(HealthArticle.getTagsFromHealthData(data));
    }

    // 计算每篇文章的匹配度
    final scoredArticles = allArticles.map((article) {
      return MapEntry(article, article.matchScore(userTags));
    }).toList();

    // 按匹配度排序
    scoredArticles.sort((a, b) => b.value.compareTo(a.value));

    // 取前5篇推荐文章
    recommendedArticles.value = scoredArticles
        .take(5)
        .where((e) => e.value > 0)
        .map((e) => e.key)
        .toList();

    // 如果没有匹配的，返回热门文章
    if (recommendedArticles.isEmpty) {
      recommendedArticles.value = allArticles.take(5).toList();
    }
  }

  /// 刷新推荐
  void refreshRecommendations() {
    _generateRecommendations();
  }

  /// 获取过滤后的文章列表
  List<HealthArticle> get filteredArticles {
    var articles = allArticles.toList();

    // 按分类筛选
    if (selectedCategory.value != null) {
      articles = articles.where((a) => a.category == selectedCategory.value).toList();
    }

    // 按搜索关键词筛选
    if (searchKeyword.value.isNotEmpty) {
      final keyword = searchKeyword.value.toLowerCase();
      articles = articles.where((a) =>
          a.title.toLowerCase().contains(keyword) ||
          a.summary.toLowerCase().contains(keyword)).toList();
    }

    return articles;
  }

  /// 获取分类文章数量
  int getCategoryCount(ContentCategory category) {
    return allArticles.where((a) => a.category == category).length;
  }

  /// 切换收藏状态
  Future<void> toggleBookmark(String articleId) async {
    if (bookmarkedArticleIds.contains(articleId)) {
      bookmarkedArticleIds.remove(articleId);
    } else {
      bookmarkedArticleIds.add(articleId);
    }
    await _saveBookmarks();
  }

  /// 检查是否已收藏
  bool isBookmarked(String articleId) {
    return bookmarkedArticleIds.contains(articleId);
  }

  /// 获取收藏的文章
  List<HealthArticle> get bookmarkedArticles {
    return allArticles.where((a) => bookmarkedArticleIds.contains(a.id)).toList();
  }

  /// 按分类筛选
  void filterByCategory(ContentCategory? category) {
    selectedCategory.value = category;
  }

  /// 搜索
  void search(String keyword) {
    searchKeyword.value = keyword;
  }

  /// 清除搜索
  void clearSearch() {
    searchKeyword.value = '';
  }

  /// 模拟文章数据
  List<HealthArticle> _getMockArticles() {
    return [
      HealthArticle(
        id: '1',
        title: '高血压患者的日常饮食指南',
        summary: '了解如何通过合理饮食控制血压，减少并发症风险，推荐8类降压食物。',
        content: '''
# 高血压患者的日常饮食指南

## 低盐饮食的重要性
盐是导致高血压的重要因素之一。建议每日盐摄入量控制在6克以内。

## 推荐的降压食物

### 1. 芹菜
芹菜含有丰富的芹菜素，具有扩张血管、降低血压的作用。

### 2. 香蕉
富含钾元素，有助于平衡体内的钠含量，降低血压。

### 3. 菠菜
含有镁元素，能够帮助血管放松，降低血压。

### 4. 大蒜
大蒜中的大蒜素有助于降低胆固醇和血压。

## 饮食原则
- 三餐规律，避免暴饮暴食
- 多吃蔬菜水果，少油少盐
- 限制酒精摄入
- 避免高脂肪食物
        ''',
        coverImage: 'https://images.unsplash.com/photo-1490645935967-10de6ba17061?w=800',
        category: ContentCategory.diet,
        tags: [ContentTag.bloodPressureHigh, ContentTag.bloodPressureControl, ContentTag.dailyCare],
        author: '王医生',
        readTime: 8,
        publishTime: DateTime.now().subtract(const Duration(days: 2)),
        viewCount: 1234,
        isRecommended: true,
      ),

      HealthArticle(
        id: '2',
        title: '心率过快的危害与调理方法',
        summary: '静息心率超过100次/分称为心动过速，了解原因和调理方法很重要。',
        content: '''
# 心率过快的危害与调理方法

## 什么是心动过速
正常成年人的静息心率在60-100次/分钟之间。超过100次/分钟称为心动过速。

## 常见原因
- 压力和焦虑
- 过度劳累
- 咖啡因摄入过多
- 贫血
- 甲状腺功能亢进

## 调理方法

### 1. 放松训练
深呼吸、冥想、瑜伽等放松技巧可以有效降低心率。

### 2. 规律运动
每周进行3-5次有氧运动，如快走、游泳、骑自行车。

### 3. 充足睡眠
保证每天7-8小时的优质睡眠。

### 4. 限制咖啡因
减少咖啡、茶、功能饮料的摄入。
        ''',
        coverImage: 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=800',
        category: ContentCategory.knowledge,
        tags: [ContentTag.heartRateHigh, ContentTag.heartHealth],
        author: '李医生',
        readTime: 6,
        publishTime: DateTime.now().subtract(const Duration(days: 5)),
        viewCount: 892,
      ),

      HealthArticle(
        id: '3',
        title: '糖尿病患者的血糖监测指南',
        summary: '掌握正确的血糖监测方法和频率，更好地控制糖尿病。',
        content: '''
# 糖尿病患者的血糖监测指南

## 监测频率
- **血糖控制稳定**：每周2-4次
- **血糖不稳定**：每天监测
- **调整治疗方案期间**：每天监测4-7次

## 监测时间点
1. 空腹血糖（早餐前）
2. 餐后2小时血糖
3. 睡前血糖
4. 夜间血糖（必要时）

## 目标范围
- 空腹血糖：4.4-7.0 mmol/L
- 餐后2小时：< 10.0 mmol/L

## 监测注意事项
- 使用干净的双手
- 正确的采血方法
- 记录监测结果
- 定期校准血糖仪
        ''',
        coverImage: 'https://images.unsplash.com/photo-1584515933487-779824d29309?w=800',
        category: ContentCategory.disease,
        tags: [ContentTag.bloodSugarHigh, ContentTag.diabetes],
        author: '张医生',
        readTime: 7,
        publishTime: DateTime.now().subtract(const Duration(days: 1)),
        viewCount: 2156,
        isRecommended: true,
      ),

      HealthArticle(
        id: '4',
        title: '老年人科学运动指南',
        summary: '适合老年人的运动方式和注意事项，保持身体健康。',
        content: '''
# 老年人科学运动指南

## 推荐运动方式

### 1. 散步
每天30分钟，每周5次。是最安全、最简单的运动方式。

### 2. 太极拳
有助于平衡能力和柔韧性的提高，预防跌倒。

### 3. 游泳
对关节冲击小，全身锻炼效果好。

### 4. 广场舞
既能锻炼身体，又能社交互动。

## 运动注意事项
- 运动前做好热身
- 运动中量力而行
- 运动后适当拉伸
- 随身携带急救药品
- 避免恶劣天气运动

## 运动强度
老年人的适宜运动心率 = (220 - 年龄) × 60%-70%
        ''',
        coverImage: 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=800',
        category: ContentCategory.senior,
        tags: [ContentTag.healthMaintenance, ContentTag.dailyCare],
        author: '赵医生',
        readTime: 5,
        publishTime: DateTime.now().subtract(const Duration(days: 7)),
        viewCount: 1567,
      ),

      HealthArticle(
        id: '5',
        title: '健康减肥的正确打开方式',
        summary: '科学减肥不节食，掌握正确的饮食和运动方法。',
        content: '''
# 健康减肥的正确打开方式

## 减肥的基本原则
1. 每周减重0.5-1公斤为宜
2. 不节食，而是合理控制饮食
3. 结合运动提高基础代谢率

## 饮食建议

### 早餐要吃好
- 鸡蛋 + 牛奶 + 全麦面包
- 或燕麦粥 + 水果

### 午餐要吃饱
- 适量主食（糙米/红薯）
- 足够的蔬菜
- 优质蛋白（鱼/鸡胸肉/豆制品）

### 晚餐要吃少
- 以蔬菜为主
- 少主食
- 晚餐后不吃零食

## 运动建议
- 有氧运动：每周3-5次，每次30分钟以上
- 力量训练：每周2-3次
- 日常活动：多走路、少坐电梯
        ''',
        coverImage: 'https://images.unsplash.com/photo-1576678927484-cc907957088c?w=800',
        category: ContentCategory.exercise,
        tags: [ContentTag.obesity, ContentTag.weightLoss],
        author: '刘教练',
        readTime: 10,
        publishTime: DateTime.now().subtract(const Duration(days: 3)),
        viewCount: 3421,
        isRecommended: true,
      ),

      HealthArticle(
        id: '6',
        title: '低血压的日常调理方法',
        summary: '低血压患者如何通过生活方式改善症状。',
        content: '''
# 低血压的日常调理方法

## 症状识别
- 头晕、乏力
- 站立时眼前发黑
- 注意力不集中
- 手脚冰凉

## 日常调理

### 饮食调理
- 适量增加盐的摄入（在医生指导下）
- 多喝水，增加血容量
- 少量多餐，避免餐后低血压

### 生活习惯
- 起床时动作缓慢
- 避免长时间站立
- 穿弹力袜
- 适当运动增强体质

### 应急处理
出现头晕时：
1. 立即坐下或躺下
2. 抬高双腿
3. 补充水分和盐分
        ''',
        coverImage: 'https://images.unsplash.com/photo-1505576399279-565b52d4ac71?w=800',
        category: ContentCategory.knowledge,
        tags: [ContentTag.bloodPressureLow],
        author: '陈医生',
        readTime: 5,
        publishTime: DateTime.now().subtract(const Duration(days: 10)),
        viewCount: 654,
      ),

      HealthArticle(
        id: '7',
        title: '心理健康与身体健康的关系',
        summary: '心理状态对身体健康的影响，如何保持心理健康。',
        content: '''
# 心理健康与身体健康的关系

## 相互影响
- 长期压力可能导致高血压
- 焦虑可能引起心率加快
- 抑郁会影响免疫系统

## 保持心理健康的方法

### 1. 正念冥想
每天10-15分钟，有助于减轻压力和焦虑。

### 2. 社交互动
与家人朋友保持联系，避免孤独感。

### 3. 培养爱好
做一些让自己开心的事情，转移注意力。

### 4. 寻求帮助
当感到压力过大时，及时寻求专业帮助。

### 5. 规律作息
保持规律的睡眠习惯，有助于情绪稳定。
        ''',
        coverImage: 'https://images.unsplash.com/photo-1499209974431-9dddcece7f88?w=800',
        category: ContentCategory.mental,
        tags: [ContentTag.healthMaintenance, ContentTag.dailyCare],
        author: '心理师林医生',
        readTime: 8,
        publishTime: DateTime.now().subtract(const Duration(days: 4)),
        viewCount: 1876,
      ),

      HealthArticle(
        id: '8',
        title: '发烧时的家庭护理',
        summary: '如何正确应对发烧，家庭护理的注意事项。',
        content: '''
# 发烧时的家庭护理

## 何时需要就医
- 体温超过39°C
- 发烧持续超过3天
- 伴有严重头痛、呼吸困难
- 婴儿3个月以下发烧

## 家庭护理方法

### 物理降温
- 温水擦浴
- 减少衣物
- 保持室内通风
- 多喝水

### 休息与营养
- 充分休息
- 清淡易消化的食物
- 补充维生素C

### 药物使用
- 退烧药按医嘱使用
- 注意用药间隔
- 避免多种退烧药混用

## 注意事项
- 不要捂汗
- 定期测量体温
- 观察其他症状
        ''',
        coverImage: 'https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?w=800',
        category: ContentCategory.disease,
        tags: [ContentTag.fever, ContentTag.dailyCare],
        author: '儿科周医生',
        readTime: 6,
        publishTime: DateTime.now().subtract(const Duration(hours: 12)),
        viewCount: 432,
      ),
    ];
  }
}
