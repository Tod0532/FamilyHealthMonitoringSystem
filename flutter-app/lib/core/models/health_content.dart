import 'package:flutter/material.dart';
import 'package:health_center_app/core/models/health_data.dart';

/// 内容分类
enum ContentCategory {
  knowledge('健康知识', Icons.school, Color(0xFF4CAF50)),
  diet('饮食建议', Icons.restaurant, Color(0xFFFF9800)),
  exercise('运动指导', Icons.directions_run, Color(0xFF2196F3)),
  disease('疾病预防', Icons.medical_services, Color(0xFFF44336)),
  mental('心理健康', Icons.psychology, Color(0xFF9C27B0)),
  senior('老年关怀', Icons.elderly, Color(0xFF00BCD4));

  final String label;
  final IconData icon;
  final Color color;

  const ContentCategory(this.label, this.icon, this.color);

  static ContentCategory fromString(String value) {
    return ContentCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ContentCategory.knowledge,
    );
  }
}

/// 内容标签（用于匹配推荐）
enum ContentTag {
  // 血压相关
  bloodPressureHigh('高血压'),
  bloodPressureLow('低血压'),
  bloodPressureControl('血压控制'),

  // 心率相关
  heartRateHigh('心率过快'),
  heartRateLow('心率过慢'),
  heartHealth('心脏健康'),

  // 血糖相关
  bloodSugarHigh('高血糖'),
  bloodSugarLow('低血糖'),
  diabetes('糖尿病'),

  // 体温相关
  fever('发烧'),
  temperatureLow('体温偏低'),

  // 体重相关
  weightLoss('减肥'),
  weightGain('增重'),
  obesity('肥胖'),

  // 通用
  healthMaintenance('健康保养'),
  dailyCare('日常护理');

  final String label;

  const ContentTag(this.label);

  static ContentTag? fromString(String value) {
    try {
      return ContentTag.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return null;
    }
  }
}

/// 健康文章模型
class HealthArticle {
  final String id;
  final String title;
  final String summary;
  final String content;
  final String coverImage;
  final ContentCategory category;
  final List<ContentTag> tags;
  final String author;
  final int readTime; // 阅读时间（分钟）
  final DateTime publishTime;
  final int viewCount;
  final bool isRecommended;
  final String? sourceUrl;

  HealthArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.coverImage,
    required this.category,
    required this.tags,
    required this.author,
    required this.readTime,
    required this.publishTime,
    this.viewCount = 0,
    this.isRecommended = false,
    this.sourceUrl,
  });

  /// 根据健康数据级别获取相关标签
  static List<ContentTag> getTagsFromHealthData(HealthData data) {
    final List<ContentTag> tags = [];

    switch (data.type) {
      case HealthDataType.bloodPressure:
        if (data.level == HealthDataLevel.high) {
          tags.addAll([ContentTag.bloodPressureHigh, ContentTag.bloodPressureControl]);
        } else if (data.level == HealthDataLevel.low) {
          tags.addAll([ContentTag.bloodPressureLow, ContentTag.bloodPressureControl]);
        }
        break;

      case HealthDataType.heartRate:
        if (data.level == HealthDataLevel.high) {
          tags.addAll([ContentTag.heartRateHigh, ContentTag.heartHealth]);
        } else if (data.level == HealthDataLevel.low) {
          tags.addAll([ContentTag.heartRateLow, ContentTag.heartHealth]);
        }
        tags.add(ContentTag.heartHealth);
        break;

      case HealthDataType.bloodSugar:
        if (data.level == HealthDataLevel.high) {
          tags.addAll([ContentTag.bloodSugarHigh, ContentTag.diabetes]);
        } else if (data.level == HealthDataLevel.low) {
          tags.add(ContentTag.bloodSugarLow);
        }
        break;

      case HealthDataType.temperature:
        if (data.level == HealthDataLevel.high) {
          tags.add(ContentTag.fever);
        } else if (data.level == HealthDataLevel.low) {
          tags.add(ContentTag.temperatureLow);
        }
        break;

      case HealthDataType.weight:
        if (data.level == HealthDataLevel.high) {
          tags.addAll([ContentTag.obesity, ContentTag.weightLoss]);
        } else if (data.level == HealthDataLevel.low) {
          tags.add(ContentTag.weightGain);
        }
        break;

      default:
        tags.add(ContentTag.healthMaintenance);
    }

    return tags;
  }

  /// 计算文章与标签的匹配度
  double matchScore(List<ContentTag> userTags) {
    if (userTags.isEmpty) return 0;
    final matchCount = tags.where((tag) => userTags.contains(tag)).length;
    return matchCount / userTags.length;
  }

  factory HealthArticle.fromJson(Map<String, dynamic> json) {
    return HealthArticle(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      summary: json['summary'] ?? '',
      content: json['content'] ?? '',
      coverImage: json['coverImage'] ?? '',
      category: ContentCategory.fromString(json['category'] ?? 'knowledge'),
      tags: (json['tags'] as List?)
              ?.map((e) => ContentTag.fromString(e.toString()))
              .whereType<ContentTag>()
              .toList() ??
          [],
      author: json['author'] ?? '健康中心',
      readTime: json['readTime'] ?? 5,
      publishTime: json['publishTime'] != null
          ? DateTime.parse(json['publishTime'])
          : DateTime.now(),
      viewCount: json['viewCount'] ?? 0,
      isRecommended: json['isRecommended'] ?? false,
      sourceUrl: json['sourceUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'content': content,
      'coverImage': coverImage,
      'category': category.name,
      'tags': tags.map((e) => e.name).toList(),
      'author': author,
      'readTime': readTime,
      'publishTime': publishTime.toIso8601String(),
      'viewCount': viewCount,
      'isRecommended': isRecommended,
      'sourceUrl': sourceUrl,
    };
  }
}

/// 文章收藏记录
class ArticleBookmark {
  final String id;
  final String articleId;
  final DateTime createTime;

  ArticleBookmark({
    required this.id,
    required this.articleId,
    required this.createTime,
  });

  factory ArticleBookmark.fromJson(Map<String, dynamic> json) {
    return ArticleBookmark(
      id: json['id']?.toString() ?? '',
      articleId: json['articleId']?.toString() ?? '',
      createTime: json['createTime'] != null
          ? DateTime.parse(json['createTime'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'articleId': articleId,
      'createTime': createTime.toIso8601String(),
    };
  }
}
