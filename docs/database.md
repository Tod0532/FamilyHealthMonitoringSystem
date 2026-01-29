# 家庭健康中心APP - 数据库设计

> 最后更新时间：2026-01-29
> 数据库版本：MySQL 8.0+
> 字符集：utf8mb4
> 存储引擎：InnoDB

---

## 📊 数据库概览

```
health_center_db
├── user                 # 用户表
├── family               # 家庭表
├── family_member        # 家庭成员表
├── health_data          # 健康数据表
├── health_data_202601   # 健康数据分表(按月)
├── health_data_202602   # 健康数据分表(按月)
├── ...
├── warning_rule         # 预警规则表
├── warning_record       # 预警记录表
├── health_content       # 健康内容表
├── device               # 设备表
├── device_binding       # 设备绑定关系表
├── health_diary         # 健康日记表
├── family_activity      # 家庭活动表
└── activity_participant # 活动参与记录表
```

---

## 📋 表结构详细设计

### 1. user（用户表）

存储APP注册用户信息，支持手机号登录。

| 字段名 | 类型 | 长度 | 可空 | 默认值 | 索引 | 说明 |
|--------|------|------|------|--------|------|------|
| id | BIGINT | - | NO | - | PK | 主键（雪花算法） |
| phone | VARCHAR | 20 | NO | - | UK | 手机号（唯一） |
| password | VARCHAR | 255 | NO | - | - | 密码（BCrypt加密） |
| nickname | VARCHAR | 50 | YES | - | - | 昵称 |
| avatar | VARCHAR | 500 | YES | - | - | 头像URL |
| role | VARCHAR | 20 | NO | USER | - | 角色（ADMIN/USER/GUEST） |
| status | VARCHAR | 20 | NO | ACTIVE | - | 状态（ACTIVE/DISABLED） |
| last_login_time | DATETIME | - | YES | - | - | 最后登录时间 |
| create_time | DATETIME | - | NO | CURRENT_TIMESTAMP | - | 创建时间 |
| update_time | DATETIME | - | NO | CURRENT_TIMESTAMP | - | 更新时间 |
| is_deleted | TINYINT | - | NO | 0 | - | 删除标记（0未删除/1已删除） |

**索引设计**
```sql
PRIMARY KEY (id)
UNIQUE KEY uk_phone (phone)
INDEX idx_status (status)
INDEX idx_create_time (create_time)
```

---

### 2. family（家庭表）

存储家庭基础信息，一个用户可创建多个家庭。

| 字段名 | 类型 | 长度 | 可空 | 默认值 | 索引 | 说明 |
|--------|------|------|------|--------|------|------|
| id | BIGINT | - | NO | - | PK | 主键 |
| name | VARCHAR | 100 | NO | - | - | 家庭名称 |
| admin_id | BIGINT | - | NO | - | FK | 管理员用户ID |
| avatar | VARCHAR | 500 | YES | - | - | 家庭头像URL |
| health_score | INT | - | NO | 0 | - | 家庭健康评分（0-100） |
| is_default | BOOLEAN | - | NO | FALSE | - | 是否默认家庭 |
| create_time | DATETIME | - | NO | CURRENT_TIMESTAMP | - | 创建时间 |
| update_time | DATETIME | - | NO | CURRENT_TIMESTAMP | - | 更新时间 |
| is_deleted | TINYINT | - | NO | 0 | - | 删除标记 |

**索引设计**
```sql
PRIMARY KEY (id)
FOREIGN KEY (admin_id) REFERENCES user(id)
INDEX idx_admin (admin_id)
INDEX idx_health_score (health_score)
```

---

### 3. family_member（家庭成员表）

存储家庭成员详情，非注册用户也可被添加。

| 字段名 | 类型 | 长度 | 可空 | 默认值 | 索引 | 说明 |
|--------|------|------|------|--------|------|------|
| id | BIGINT | - | NO | - | PK | 主键 |
| family_id | BIGINT | - | NO | - | FK | 家庭ID |
| user_id | BIGINT | - | YES | - | FK | 关联用户ID（可选） |
| name | VARCHAR | 50 | NO | - | - | 成员姓名 |
| age | INT | - | YES | - | - | 年龄 |
| gender | VARCHAR | 10 | YES | - | - | 性别（MALE/FEMALE） |
| relationship | VARCHAR | 50 | NO | - | - | 关系（父母/子女/配偶等） |
| medical_history | TEXT | - | YES | - | - | 基础病史（AES加密） |
| allergies | TEXT | - | YES | - | - | 过敏史（AES加密） |
| blood_type | VARCHAR | 10 | YES | - | - | 血型 |
| height | DECIMAL | 5,2 | YES | - | - | 身高（cm） |
| weight | DECIMAL | 5,2 | YES | - | - | 体重（kg） |
| avatar | VARCHAR | 500 | YES | - | - | 头像URL |
| creator_id | BIGINT | - | NO | - | FK | 创建人ID |
| create_time | DATETIME | - | NO | CURRENT_TIMESTAMP | - | 创建时间 |
| update_time | DATETIME | - | NO | CURRENT_TIMESTAMP | - | 更新时间 |
| is_deleted | TINYINT | - | NO | 0 | - | 删除标记 |

**索引设计**
```sql
PRIMARY KEY (id)
FOREIGN KEY (family_id) REFERENCES family(id)
FOREIGN KEY (user_id) REFERENCES user(id)
INDEX idx_family (family_id)
INDEX idx_user (user_id)
```

---

### 4. health_data（健康数据表）

存储所有家庭成员的健康指标数据，按月分表。

| 字段名 | 类型 | 长度 | 可空 | 默认值 | 索引 | 说明 |
|--------|------|------|------|--------|------|------|
| id | BIGINT | - | NO | - | PK | 主键 |
| member_id | BIGINT | - | NO | - | FK | 成员ID |
| metric_type | VARCHAR | 20 | NO | - | - | 指标类型 |
| metric_value | VARCHAR | 50 | NO | - | - | 指标值 |
| unit | VARCHAR | 20 | YES | - | - | 单位 |
| record_time | DATETIME | - | NO | - | - | 记录时间 |
| input_method | VARCHAR | 20 | NO | MANUAL | - | 录入方式（MANUAL/DEVICE） |
| device_id | VARCHAR | 100 | YES | - | - | 设备ID |
| extra_data | JSON | - | YES | - | - | 额外数据（如血压舒张压） |
| input_user_id | BIGINT | - | NO | - | FK | 录入人ID |
| is_synced | BOOLEAN | - | NO | TRUE | - | 是否已同步 |
| create_time | DATETIME | - | NO | CURRENT_TIMESTAMP | - | 创建时间 |

**指标类型枚举（metric_type）**
| 代码 | 名称 | 单位 | 说明 |
|------|------|------|------|
| BP_SYS | 收缩压 | mmHg | 血压高压 |
| BP_DIA | 舒张压 | mmHg | 血压低压 |
| BG_FASTING | 空腹血糖 | mmol/L | 空腹血糖 |
| BG_POSTPRANDIAL | 餐后血糖 | mmol/L | 餐后血糖 |
| WEIGHT | 体重 | kg | 体重 |
| HEIGHT | 身高 | cm | 身高 |
| HR | 心率 | bpm | 心率 |
| SLEEP | 睡眠时长 | h | 睡眠时长 |
| VISION_L | 左眼视力 | - | 裸眼/矫正 |
| VISION_R | 右眼视力 | - | 裸眼/矫正 |
| TEMP | 体温 | ℃ | 体温 |

**索引设计**
```sql
PRIMARY KEY (id)
FOREIGN KEY (member_id) REFERENCES family_member(id)
INDEX idx_member_time (member_id, record_time DESC)
INDEX idx_metric_type (metric_type)
INDEX idx_record_time (record_time)
```

---

### 5. warning_rule（预警规则表）

存储各成员各指标的预警规则配置。

| 字段名 | 类型 | 长度 | 可空 | 默认值 | 索引 | 说明 |
|--------|------|------|------|--------|------|------|
| id | BIGINT | - | NO | - | PK | 主键 |
| member_id | BIGINT | - | NO | - | FK | 成员ID |
| metric_type | VARCHAR | 20 | NO | - | - | 指标类型 |
| threshold_min | DECIMAL | 10,2 | YES | - | - | 阈值下限 |
| threshold_max | DECIMAL | 10,2 | YES | - | - | 阈值上限 |
| compare_type | VARCHAR | 10 | NO | BETWEEN | - | 比较类型（BETWEEN/GT/LT） |
| is_custom | BOOLEAN | - | NO | FALSE | - | 是否自定义 |
| is_active | BOOLEAN | - | NO | TRUE | - | 是否生效 |
| continuous_count | INT | - | NO | 1 | - | 连续异常次数触发 |
| creator_id | BIGINT | - | NO | - | FK | 创建人ID |
| create_time | DATETIME | - | NO | CURRENT_TIMESTAMP | - | 创建时间 |
| update_time | DATETIME | - | NO | CURRENT_TIMESTAMP | - | 更新时间 |

**索引设计**
```sql
PRIMARY KEY (id)
FOREIGN KEY (member_id) REFERENCES family_member(id)
UNIQUE KEY uk_member_metric (member_id, metric_type)
INDEX idx_active (is_active)
```

---

### 6. warning_record（预警记录表）

存储历史预警信息，跟踪处理状态。

| 字段名 | 类型 | 长度 | 可空 | 默认值 | 索引 | 说明 |
|--------|------|------|------|--------|------|------|
| id | BIGINT | - | NO | - | PK | 主键 |
| member_id | BIGINT | - | NO | - | FK | 成员ID |
| family_id | BIGINT | - | NO | - | FK | 家庭ID |
| rule_id | BIGINT | - | YES | - | FK | 规则ID |
| metric_type | VARCHAR | 20 | NO | - | - | 指标类型 |
| abnormal_value | VARCHAR | 50 | NO | - | - | 异常值 |
| warning_level | VARCHAR | 20 | NO | NORMAL | - | 预警级别（LOW/MEDIUM/HIGH/URGENT） |
| warning_time | DATETIME | - | NO | CURRENT_TIMESTAMP | - | 预警时间 |
| status | VARCHAR | 20 | NO | PENDING | - | 处理状态 |
| receivers | JSON | - | YES | - | - | 接收人ID列表 |
| push_methods | JSON | - | YES | - | - | 推送方式列表 |
| remark | TEXT | - | YES | - | - | 备注 |
| handler_id | BIGINT | - | YES | - | FK | 处理人ID |
| handled_time | DATETIME | - | YES | - | - | 处理时间 |
| create_time | DATETIME | - | NO | CURRENT_TIMESTAMP | - | 创建时间 |

**处理状态枚举（status）**
| 状态 | 说明 |
|------|------|
| PENDING | 未处理 |
| VIEWED | 已查看 |
| HANDLED | 已处理 |
| MEDICAL | 已就医 |

**索引设计**
```sql
PRIMARY KEY (id)
FOREIGN KEY (member_id) REFERENCES family_member(id)
FOREIGN KEY (family_id) REFERENCES family(id)
INDEX idx_status_time (status, warning_time DESC)
INDEX idx_member (member_id)
INDEX idx_family (family_id)
```

---

### 7. health_content（健康内容表）

存储健康活动、食谱等内容。

| 字段名 | 类型 | 长度 | 可空 | 默认值 | 索引 | 说明 |
|--------|------|------|------|--------|------|------|
| id | BIGINT | - | NO | - | PK | 主键 |
| content_type | VARCHAR | 20 | NO | - | - | 内容类型（ACTIVITY/RECIPE） |
| title | VARCHAR | 200 | NO | - | - | 标题 |
| summary | VARCHAR | 500 | YES | - | - | 摘要 |
| content | TEXT | - | NO | - | - | 详情内容 |
| cover_image | VARCHAR | 500 | YES | - | - | 封面图URL |
| tags | JSON | - | YES | - | - | 标签数组 |
| target_audience | JSON | - | YES | - | - | 适应人群 |
| difficulty | VARCHAR | 20 | YES | - | - | 难度（仅活动） |
| duration | INT | - | YES | - | - | 时长（分钟，仅活动） |
| calories | INT | - | YES | - | - | 热量（kcal，仅食谱） |
| nutrition | JSON | - | YES | - | - | 营养成分 |
| ingredients | JSON | - | YES | - | - | 食材清单 |
| steps | JSON | - | YES | - | - | 制作步骤 |
| audit_status | VARCHAR | 20 | NO | PENDING | - | 审核状态 |
| source | VARCHAR | 100 | YES | - | - | 来源 |
| view_count | INT | - | NO | 0 | - | 浏览次数 |
| favorite_count | INT | - | NO | 0 | - | 收藏次数 |
| create_time | DATETIME | - | NO | CURRENT_TIMESTAMP | - | 创建时间 |
| update_time | DATETIME | - | NO | CURRENT_TIMESTAMP | - | 更新时间 |

**索引设计**
```sql
PRIMARY KEY (id)
INDEX idx_type_aud (content_type, audit_status)
INDEX idx_tags ((CAST(tags AS CHAR(255) ARRAY)))
INDEX idx_view_count (view_count DESC)
```

---

### 8. device（设备表）

存储已适配的智能健康设备信息。

| 字段名 | 类型 | 长度 | 可空 | 默认值 | 索引 | 说明 |
|--------|------|------|------|--------|------|------|
| id | BIGINT | - | NO | - | PK | 主键 |
| device_name | VARCHAR | 100 | NO | - | - | 设备名称 |
| brand | VARCHAR | 50 | NO | - | - | 品牌 |
| model | VARCHAR | 100 | NO | - | UK | 型号 |
| device_type | VARCHAR | 20 | NO | - | - | 设备类型 |
| connection_type | VARCHAR | 20 | NO | - | - | 连接方式（BLE/WIFI） |
| protocol | VARCHAR | 50 | YES | - | - | 协议类型 |
| supported_metrics | JSON | - | NO | - | - | 支持的指标 |
| is_supported | BOOLEAN | - | NO | TRUE | - | 是否已适配 |
| create_time | DATETIME | - | NO | CURRENT_TIMESTAMP | - | 创建时间 |

**设备类型枚举（device_type）**
| 代码 | 名称 |
|------|------|
| BP_MONITOR | 血压计 |
| BG_METER | 血糖仪 |
| BODY_SCALE | 体脂秤 |
| THERMOMETER | 体温计 |
| HR_MONITOR | 心率带 |
| SLEEP_MONITOR | 睡眠监测器 |

---

### 9. device_binding（设备绑定关系表）

存储用户与设备的绑定关系。

| 字段名 | 类型 | 长度 | 可空 | 默认值 | 索引 | 说明 |
|--------|------|------|------|--------|------|------|
| id | BIGINT | - | NO | - | PK | 主键 |
| user_id | BIGINT | - | NO | - | FK | 用户ID |
| device_id | BIGINT | - | NO | - | FK | 设备ID |
| device_mac | VARCHAR | 100 | NO | - | - | 设备MAC地址 |
| member_id | BIGINT | - | YES | - | FK | 关联成员ID |
| nickname | VARCHAR | 50 | YES | - | - | 设备昵称 |
| last_sync_time | DATETIME | - | YES | - | - | 最后同步时间 |
| is_active | BOOLEAN | - | NO | TRUE | - | 是否启用 |
| create_time | DATETIME | - | NO | CURRENT_TIMESTAMP | - | 绑定时间 |
| update_time | DATETIME | - | NO | CURRENT_TIMESTAMP | - | 更新时间 |

**索引设计**
```sql
PRIMARY KEY (id)
FOREIGN KEY (user_id) REFERENCES user(id)
FOREIGN KEY (device_id) REFERENCES device(id)
UNIQUE KEY uk_mac (device_mac)
INDEX idx_user (user_id)
```

---

### 10. health_diary（健康日记表）

存储家庭成员的健康日记记录。

| 字段名 | 类型 | 长度 | 可空 | 默认值 | 索引 | 说明 |
|--------|------|------|------|--------|------|------|
| id | BIGINT | - | NO | - | PK | 主键 |
| member_id | BIGINT | - | NO | - | FK | 成员ID |
| diary_date | DATE | - | NO | - | - | 日记日期 |
| content | TEXT | - | NO | - | - | 日记内容 |
| mood | VARCHAR | 20 | YES | - | - | 心情状态 |
| symptoms | JSON | - | YES | - | - | 症状记录 |
| medication | JSON | - | YES | - | - | 用药记录 |
| images | JSON | - | YES | - | - | 图片列表 |
| creator_id | BIGINT | - | NO | - | FK | 创建人ID |
| create_time | DATETIME | - | NO | CURRENT_TIMESTAMP | - | 创建时间 |
| update_time | DATETIME | - | NO | CURRENT_TIMESTAMP | - | 更新时间 |

**索引设计**
```sql
PRIMARY KEY (id)
FOREIGN KEY (member_id) REFERENCES family_member(id)
UNIQUE KEY uk_member_date (member_id, diary_date)
INDEX idx_diary_date (diary_date DESC)
```

---

### 11. family_activity（家庭活动表）

存储家庭健康打卡活动。

| 字段名 | 类型 | 长度 | 可空 | 默认值 | 索引 | 说明 |
|--------|------|------|------|--------|------|------|
| id | BIGINT | - | NO | - | PK | 主键 |
| family_id | BIGINT | - | NO | - | FK | 家庭ID |
| activity_name | VARCHAR | 100 | NO | - | - | 活动名称 |
| activity_type | VARCHAR | 20 | NO | - | - | 活动类型 |
| target_value | INT | - | NO | - | - | 目标值 |
| unit | VARCHAR | 20 | NO | - | - | 单位 |
| start_date | DATE | - | NO | - | - | 开始日期 |
| end_date | DATE | - | YES | - | - | 结束日期 |
| is_recurring | BOOLEAN | - | NO | FALSE | - | 是否循环 |
| recurring_pattern | VARCHAR | 50 | YES | - | - | 循环模式 |
| status | VARCHAR | 20 | NO | ACTIVE | - | 状态 |
| creator_id | BIGINT | - | NO | - | FK | 创建人ID |
| create_time | DATETIME | - | NO | CURRENT_TIMESTAMP | - | 创建时间 |

**索引设计**
```sql
PRIMARY KEY (id)
FOREIGN KEY (family_id) REFERENCES family(id)
INDEX idx_family_status (family_id, status)
INDEX idx_date_range (start_date, end_date)
```

---

### 12. activity_participant（活动参与记录表）

存储成员参与家庭活动的打卡记录。

| 字段名 | 类型 | 长度 | 可空 | 默认值 | 索引 | 说明 |
|--------|------|------|------|--------|------|------|
| id | BIGINT | - | NO | - | PK | 主键 |
| activity_id | BIGINT | - | NO | - | FK | 活动ID |
| member_id | BIGINT | - | NO | - | FK | 成员ID |
| record_date | DATE | - | NO | - | - | 打卡日期 |
| actual_value | INT | - | NO | - | - | 实际完成值 |
| note | VARCHAR | 500 | YES | - | - | 备注 |
| images | JSON | - | YES | - | - | 图片证明 |
| create_time | DATETIME | - | NO | CURRENT_TIMESTAMP | - | 创建时间 |

**索引设计**
```sql
PRIMARY KEY (id)
FOREIGN KEY (activity_id) REFERENCES family_activity(id)
FOREIGN KEY (member_id) REFERENCES family_member(id)
UNIQUE KEY uk_activity_member_date (activity_id, member_id, record_date)
INDEX idx_record_date (record_date DESC)
```

---

## 🔧 分表策略

### health_data 按月分表

```sql
-- 每月一张分表，命名规则：health_data_YYYYMM
-- 例如：health_data_202601, health_data_202602, ...

-- 创建分表示例
CREATE TABLE health_data_202601 LIKE health_data;

-- 数据迁移（定时任务）
-- 每月1号凌晨创建下月分表
```

---

## 🔐 数据加密方案

### 敏感字段加密

| 字段 | 加密方式 | 说明 |
|------|----------|------|
| user.password | BCrypt | 密码加密 |
| family_member.medical_history | AES-256 | 病史加密 |
| family_member.allergies | AES-256 | 过敏史加密 |

### 加密实现

```java
// AES加密工具类
public class AESUtil {
    private static final String KEY = "从配置读取";
    private static final String IV = "从配置读取";

    public static String encrypt(String data) { ... }
    public static String decrypt(String encryptedData) { ... }
}

// MyBatis拦截器自动加解密
@Intercepts({@Signature(type = Executor.class, ...)})
public class CryptoInterceptor implements Interceptor { ... }
```

---

## 📈 索引优化建议

### 高频查询优化

| 查询场景 | 索引建议 |
|----------|----------|
| 按成员+时间范围查询健康数据 | (member_id, record_time DESC) |
| 按状态+时间查询预警记录 | (status, warning_time DESC) |
| 按内容类型+审核状态查询 | (content_type, audit_status) |
| 按设备MAC查询绑定关系 | UNIQUE KEY uk_mac (device_mac) |

### 复合索引规则

1. 最左前缀原则
2. 区分度高的字段放前面
3. 覆盖索引优先

---

## 💾 备份策略

| 备份类型 | 频率 | 保留时间 |
|----------|------|----------|
| 全量备份 | 每日凌晨 | 30天 |
| 增量备份 | 每小时 | 7天 |
| 日志备份 | 实时 | 1天 |

---

*数据库设计文档，如有变更请及时更新*
