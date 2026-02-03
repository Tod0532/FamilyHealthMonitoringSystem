-- ============================================================================
-- 家庭健康中心APP - H2数据库测试数据（开发环境）
-- ============================================================================

-- ============================================================================
-- 测试用户（密码：123456）
-- ============================================================================
INSERT INTO sys_user (id, phone, password, nickname, gender, status)
VALUES (1, '13800138000', '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iKTVKIUi', '测试用户', 'male', 1);

-- ============================================================================
-- 测试家庭成员
-- ============================================================================
INSERT INTO family_member (id, user_id, name, gender, birthday, relation, role, sort_order)
VALUES
    (1, 1, '张三', 'male', '1990-01-01', 'other', 'admin', 1),
    (2, 1, '李四', 'female', '1992-05-15', 'spouse', 'member', 2),
    (3, 1, '小明', 'male', '2020-06-01', 'child', 'member', 3);

-- ============================================================================
-- 测试健康数据
-- ============================================================================
INSERT INTO health_data (id, user_id, member_id, data_type, value1, value2, unit, measure_time, data_source)
VALUES
    (1, 1, 1, 'blood_pressure', 120.0, 80.0, 'mmHg', CURRENT_TIMESTAMP, 'manual'),
    (2, 1, 1, 'heart_rate', 75.0, NULL, '次/分', CURRENT_TIMESTAMP, 'manual'),
    (3, 1, 1, 'blood_sugar', 5.5, NULL, 'mmol/L', CURRENT_TIMESTAMP, 'manual'),
    (4, 1, 1, 'temperature', 36.5, NULL, '℃', CURRENT_TIMESTAMP, 'manual'),
    (5, 1, 1, 'weight', 70.0, NULL, 'kg', CURRENT_TIMESTAMP, 'manual');

-- ============================================================================
-- 默认预警规则（系统预设）
-- ============================================================================
-- 血压预警规则
INSERT INTO alert_rule (id, user_id, alert_type, alert_level, condition_type, threshold1, threshold2, rule_name, enabled, is_default)
VALUES
    (1, 1, 'blood_pressure', 'danger', 'gt', 140.0, 90.0, '高血压预警', 1, 1),
    (2, 1, 'blood_pressure', 'warning', 'gt', 130.0, 85.0, '血压偏高预警', 1, 1),
    (3, 1, 'blood_pressure', 'warning', 'lt', 90.0, 60.0, '血压偏低预警', 1, 1);

-- 心率预警规则
INSERT INTO alert_rule (id, user_id, alert_type, alert_level, condition_type, threshold1, threshold2, rule_name, enabled, is_default)
VALUES
    (4, 1, 'heart_rate', 'danger', 'gt', 100.0, NULL, '心率过快预警', 1, 1),
    (5, 1, 'heart_rate', 'danger', 'lt', 60.0, NULL, '心率过慢预警', 1, 1);

-- 血糖预警规则
INSERT INTO alert_rule (id, user_id, alert_type, alert_level, condition_type, threshold1, threshold2, rule_name, enabled, is_default)
VALUES
    (6, 1, 'blood_sugar', 'danger', 'gt', 11.1, NULL, '血糖过高预警', 1, 1),
    (7, 1, 'blood_sugar', 'warning', 'gt', 7.8, NULL, '血糖偏高预警', 1, 1),
    (8, 1, 'blood_sugar', 'danger', 'lt', 3.9, NULL, '低血糖预警', 1, 1);

-- ============================================================================
-- 健康内容（示例）
-- ============================================================================
INSERT INTO health_content (id, category, title, summary, content, cover_image, tags, view_count, like_count, is_published, published_at)
VALUES
    (1, 'nutrition', '健康饮食金字塔指南', '了解科学饮食的基本原则，掌握健康饮食的金字塔结构。',
    '# 健康饮食金字塔指南

## 底层：谷物类
每天摄入300-500克谷物，包括米饭、面条、面包等。

## 第二层：蔬菜水果
- 蔬菜：每天400-500克
- 水果：每天200-350克

## 第三层：蛋白质类
- 畜禽肉：每天40-75克
- 鱼虾：每天40-75克
- 蛋类：每天40-50克
- 奶制品：每天300克

## 顶层：油脂盐糖
- 油：每天25-30克
- 盐：每天少于6克
- 糖：控制在25克以下', NULL, '营养,饮食,健康', 100, 20, 1, CURRENT_TIMESTAMP),

    (2, 'exercise', '每天30分钟运动指南', '科学运动，健康生活。每天30分钟，让你远离慢性病。',
    '# 每天30分钟运动指南

## 有氧运动
- 快走、慢跑、游泳、骑行
- 每周至少150分钟中等强度运动

## 力量训练
- 每周2-3次
- 针对大肌群训练

## 柔韧性训练
- 每次运动后拉伸
- 每周2-3次专门练习', NULL, '运动,健身,有氧', 80, 15, 1, CURRENT_TIMESTAMP),

    (3, 'disease', '高血压患者的日常管理', '高血压是常见的慢性病，科学管理可以有效控制。',
    '# 高血压患者的日常管理

## 血压监测
- 每天早晚各测一次
- 记录血压数据

## 饮食控制
- 低盐饮食（每天少于6克）
- 增加钾摄入
- 控制总热量

## 规律运动
- 每周150分钟中等强度运动
- 避免剧烈运动

## 药物治疗
- 遵医嘱服药
- 定期复查', NULL, '高血压,慢性病,健康管理', 120, 30, 1, CURRENT_TIMESTAMP);
