-- 测试数据（适配新表结构）

-- 清空现有数据
DELETE FROM health_data;
DELETE FROM family_member;
DELETE FROM user;

-- 用户数据 (密码: 123456 的BCrypt加密)
INSERT INTO user (id, username, password, nickname, gender, phone, avatar) VALUES
(1, 'testuser', '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iAt6Z5EH', '测试用户', 1, '13800138000', NULL);

-- 家庭成员数据
INSERT INTO family_member (id, user_id, name, relationship, gender, birthday) VALUES
(1, 1, '张三', 'father', 1, '1960-01-01'),
(2, 1, '李四', 'mother', 2, '1962-05-15'),
(3, 1, '小明', 'son', 1, '1990-10-20');

-- 健康数据
INSERT INTO health_data (user_id, member_id, data_type, value1, value2, unit, measure_time, notes) VALUES
(1, 1, 'blood_pressure', 120, 80, 'mmHg', NOW(), '血压正常'),
(1, 1, 'heart_rate', 75, NULL, 'bpm', NOW(), '心率正常'),
(1, 2, 'blood_sugar', 5.5, NULL, 'mmol/L', NOW(), '空腹血糖'),
(1, 2, 'temperature', 36.5, NULL, '℃', NOW(), '体温正常'),
(1, 3, 'weight', 70, NULL, 'kg', NOW(), '体重正常'),
(1, 3, 'height', 175, NULL, 'cm', NOW(), '身高');

SELECT '数据导入完成！' as message;
SELECT COUNT(*) as user_count FROM user;
SELECT COUNT(*) as member_count FROM family_member;
SELECT COUNT(*) as health_data_count FROM health_data;
