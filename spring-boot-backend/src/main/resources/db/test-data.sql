-- 测试数据
-- 用户数据
INSERT INTO user (id, phone, password, nickname, gender, avatar, created_at, updated_at) VALUES
(1, '13800138000', '$2a$10$N9qo8uLckk2oZ5oZ5oZ5oOq3o3o3o3o3o3o3o3o3o3o3o3o3o3o3', '测试用户', 'male', NULL, NOW(), NOW());

-- 家庭成员数据
INSERT INTO family_member (id, user_id, name, relation, gender, birthday, avatar, created_at, updated_at) VALUES
(1, 1, '张三', 'father', 'male', '1960-01-01', NULL, NOW(), NOW()),
(2, 1, '李四', 'mother', 'female', '1962-05-15', NULL, NOW(), NOW()),
(3, 1, '小明', 'son', 'male', '1990-10-20', NULL, NOW(), NOW());

-- 健康数据
INSERT INTO health_data (id, user_id, member_id, data_type, data_value, unit, status, measure_time, created_at, updated_at) VALUES
(1, 1, 1, 'blood_pressure', '120/80', 'mmHg', 'normal', NOW(), NOW(), NOW()),
(2, 1, 1, 'heart_rate', '75', 'bpm', 'normal', NOW(), NOW(), NOW()),
(3, 1, 2, 'blood_sugar', '5.5', 'mmol/L', 'normal', NOW(), NOW(), NOW()),
(4, 1, 2, 'temperature', '36.5', '℃', 'normal', NOW(), NOW(), NOW()),
(5, 1, 3, 'weight', '70', 'kg', 'normal', NOW(), NOW(), NOW());
