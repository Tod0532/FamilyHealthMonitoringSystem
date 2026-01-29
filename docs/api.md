# 家庭健康中心APP - API接口文档

> 最后更新时间：2026-01-29
> API版本：v1
> 基础URL：`https://api.healthcenter.com/api/v1`

---

## 📋 通用规范

### 请求头

```http
Content-Type: application/json
Authorization: Bearer {token}
X-Device-Id: {设备唯一标识}
X-App-Version: {APP版本号}
X-Request-Id: {请求追踪ID}
```

### 统一响应格式

```json
{
  "code": 200,
  "message": "success",
  "data": { },
  "timestamp": 1706496000000,
  "requestId": "req_123456"
}
```

### 错误码体系

| 错误码 | 说明 |
|--------|------|
| 200 | 成功 |
| 1001 | 参数错误 |
| 1002 | 缺少必填参数 |
| 1003 | 参数格式错误 |
| 2001 | Token过期 |
| 2002 | Token无效 |
| 2003 | 权限不足 |
| 3001 | 资源不存在 |
| 3002 | 资源已存在 |
| 4001 | 业务逻辑错误 |
| 5000 | 服务器内部错误 |
| 5001 | 数据库错误 |
| 5002 | 第三方服务错误 |

---

## 🔐 认证模块 (Auth)

### 1.1 发送验证码

```http
POST /auth/send-sms
```

**请求参数**
```json
{
  "phone": "13800138000",
  "type": "REGISTER"  // REGISTER/LOGIN/RESET_PASSWORD
}
```

**响应**
```json
{
  "code": 200,
  "message": "验证码已发送",
  "data": {
    "expireIn": 300  // 过期时间（秒）
  }
}
```

### 1.2 用户注册

```http
POST /auth/register
```

**请求参数**
```json
{
  "phone": "13800138000",
  "password": "123456",
  "smsCode": "123456",
  "nickname": "张三"
}
```

**响应**
```json
{
  "code": 200,
  "message": "注册成功",
  "data": {
    "userId": "10001",
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expireIn": 86400
  }
}
```

### 1.3 用户登录

```http
POST /auth/login
```

**请求参数**
```json
{
  "phone": "13800138000",
  "password": "123456"
}
```

**响应**（同注册响应）

### 1.4 刷新Token

```http
POST /auth/refresh-token
```

**请求参数**
```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### 1.5 用户登出

```http
POST /auth/logout
```

**请求头**：需要Token

---

## 👨‍👩‍👧‍👦 家庭模块 (Family)

### 2.1 获取用户家庭列表

```http
GET /families
```

**响应**
```json
{
  "code": 200,
  "data": {
    "total": 2,
    "items": [
      {
        "id": "1001",
        "name": "温馨小家",
        "avatar": "https://cdn.example.com/family1.jpg",
        "adminId": "10001",
        "adminName": "张三",
        "healthScore": 85,
        "memberCount": 4,
        "isDefault": true,
        "createTime": "2026-01-01T00:00:00"
      }
    ]
  }
}
```

### 2.2 创建家庭

```http
POST /families
```

**请求参数**
```json
{
  "name": "温馨小家",
  "avatar": "https://cdn.example.com/family1.jpg"
}
```

### 2.3 获取家庭详情

```http
GET /families/{familyId}
```

**响应**
```json
{
  "code": 200,
  "data": {
    "id": "1001",
    "name": "温馨小家",
    "avatar": "https://cdn.example.com/family1.jpg",
    "adminId": "10001",
    "adminName": "张三",
    "healthScore": 85,
    "memberCount": 4,
    "createTime": "2026-01-01T00:00:00",
    "statistics": {
      "todayRecords": 5,
      "warningCount": 1,
      "activityCount": 3
    }
  }
}
```

### 2.4 更新家庭信息

```http
PUT /families/{familyId}
```

**请求参数**
```json
{
  "name": "幸福之家",
  "avatar": "https://cdn.example.com/family2.jpg"
}
```

### 2.5 设置默认家庭

```http
PUT /families/{familyId}/set-default
```

### 2.6 删除家庭

```http
DELETE /families/{familyId}
```

### 2.7 获取家庭健康评分

```http
GET /families/{familyId}/score
```

**响应**
```json
{
  "code": 200,
  "data": {
    "totalScore": 85,
    "scoreDetails": [
      {
        "memberId": "2001",
        "memberName": "爸爸",
        "score": 90,
        "recordCount": 50,
        "warningCount": 2
      }
    ],
    "updateTime": "2026-01-29T10:00:00"
  }
}
```

---

## 👥 家庭成员模块 (Member)

### 3.1 获取家庭成员列表

```http
GET /families/{familyId}/members
```

**响应**
```json
{
  "code": 200,
  "data": {
    "items": [
      {
        "id": "2001",
        "familyId": "1001",
        "userId": "10001",
        "name": "爸爸",
        "age": 45,
        "gender": "MALE",
        "relationship": "本人",
        "avatar": "https://cdn.example.com/avatar1.jpg",
        "healthScore": 90,
        "role": "ADMIN",
        "createTime": "2026-01-01T00:00:00"
      }
    ]
  }
}
```

### 3.2 添加家庭成员

```http
POST /families/{familyId}/members
```

**请求参数**
```json
{
  "userId": null,  // 可选，关联已注册用户
  "name": "妈妈",
  "age": 42,
  "gender": "FEMALE",
  "relationship": "配偶",
  "bloodType": "A",
  "height": 165,
  "weight": 55,
  "medicalHistory": "无",  // 会被加密存储
  "allergies": "海鲜",     // 会被加密存储
  "permissions": ["VIEW", "INPUT"]
}
```

### 3.3 获取成员详情

```http
GET /members/{memberId}
```

**响应**
```json
{
  "code": 200,
  "data": {
    "id": "2001",
    "name": "爸爸",
    "age": 45,
    "gender": "MALE",
    "relationship": "本人",
    "avatar": "https://cdn.example.com/avatar1.jpg",
    "bloodType": "O",
    "height": 175,
    "weight": 70,
    "medicalHistory": "高血压",  // 已解密
    "allergies": "青霉素",       // 已解密
    "healthScore": 90,
    "role": "ADMIN",
    "permissions": ["VIEW", "INPUT", "MANAGE"],
    "statistics": {
      "recordCount": 50,
      "warningCount": 2,
      "lastRecordTime": "2026-01-29T08:00:00"
    }
  }
}
```

### 3.4 更新成员信息

```http
PUT /members/{memberId}
```

### 3.5 删除成员

```http
DELETE /members/{memberId}
```

### 3.6 分配成员权限

```http
PUT /members/{memberId}/permissions
```

**请求参数**
```json
{
  "permissions": ["VIEW", "INPUT"]
}
```

**权限类型**
| 权限 | 说明 |
|------|------|
| VIEW | 仅查看 |
| INPUT | 可录入数据 |
| MANAGE | 可管理成员和设置 |

---

## 📊 健康数据模块 (Health Data)

### 4.1 获取成员健康数据

```http
GET /members/{memberId}/health-data?page=1&size=20&metricType=BP_SYS&startDate=2026-01-01&endDate=2026-01-31
```

**查询参数**
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| page | Integer | 否 | 页码，默认1 |
| size | Integer | 否 | 每页条数，默认20 |
| metricType | String | 否 | 指标类型 |
| startDate | String | 否 | 开始日期 |
| endDate | String | 否 | 结束日期 |

**响应**
```json
{
  "code": 200,
  "data": {
    "total": 100,
    "page": 1,
    "size": 20,
    "items": [
      {
        "id": "3001",
        "memberId": "2001",
        "metricType": "BP_SYS",
        "metricValue": "135",
        "unit": "mmHg",
        "recordTime": "2026-01-29T08:00:00",
        "inputMethod": "MANUAL",
        "deviceId": null,
        "extraData": {
          "BP_DIA": "85",
          "HR": "75"
        }
      }
    ]
  }
}
```

### 4.2 录入健康数据

```http
POST /members/{memberId}/health-data
```

**请求参数**
```json
{
  "metricType": "BP_SYS",
  "metricValue": "135",
  "unit": "mmHg",
  "recordTime": "2026-01-29T08:00:00",
  "inputMethod": "MANUAL",
  "extraData": {
    "BP_DIA": "85",
    "HR": "75"
  }
}
```

### 4.3 批量录入健康数据

```http
POST /members/{memberId}/health-data/batch
```

**请求参数**
```json
{
  "records": [
    {
      "metricType": "BP_SYS",
      "metricValue": "135",
      "unit": "mmHg",
      "recordTime": "2026-01-29T08:00:00",
      "extraData": { "BP_DIA": "85", "HR": "75" }
    },
    {
      "metricType": "WEIGHT",
      "metricValue": "70",
      "unit": "kg",
      "recordTime": "2026-01-29T08:00:00"
    }
  ]
}
```

### 4.4 获取数据趋势

```http
GET /members/{memberId}/health-data/trends?metricType=BP_SYS&period=7D
```

**查询参数**
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| metricType | String | 是 | 指标类型 |
| period | String | 是 | 时间周期（7D/30D/90D/1Y） |

**响应**
```json
{
  "code": 200,
  "data": {
    "metricType": "BP_SYS",
    "unit": "mmHg",
    "period": "7D",
    "trends": [
      { "date": "2026-01-23", "value": 130 },
      { "date": "2026-01-24", "value": 132 },
      { "date": "2026-01-25", "value": 128 },
      { "date": "2026-01-26", "value": 135 },
      { "date": "2026-01-27", "value": 133 },
      { "date": "2026-01-28", "value": 130 },
      { "date": "2026-01-29", "value": 135 }
    ],
    "statistics": {
      "avg": 131.86,
      "max": 135,
      "min": 128,
      "count": 7
    }
  }
}
```

### 4.5 设备数据同步

```http
POST /members/{memberId}/health-data/sync-device
```

**请求参数**
```json
{
  "deviceId": "OMRON_BP_001",
  "deviceType": "BP_MONITOR",
  "rawData": "0x01 0x02 ...",  // 设备原始数据
  "dataFormat": "HEX"
}
```

### 4.6 导出健康数据

```http
GET /members/{memberId}/health-data/export?format=xlsx&startDate=2026-01-01&endDate=2026-01-31
```

**响应**：文件下载流

---

## ⚠️ 预警模块 (Warning)

### 5.1 获取预警规则列表

```http
GET /members/{memberId}/warning-rules
```

**响应**
```json
{
  "code": 200,
  "data": {
    "items": [
      {
        "id": "4001",
        "memberId": "2001",
        "metricType": "BP_SYS",
        "metricName": "收缩压",
        "thresholdMin": 90,
        "thresholdMax": 140,
        "compareType": "BETWEEN",
        "isCustom": false,
        "isActive": true,
        "continuousCount": 1
      }
    ]
  }
}
```

### 5.2 创建预警规则

```http
POST /members/{memberId}/warning-rules
```

**请求参数**
```json
{
  "metricType": "BP_SYS",
  "thresholdMin": 90,
  "thresholdMax": 140,
  "compareType": "BETWEEN",
  "continuousCount": 1
}
```

### 5.3 更新预警规则

```http
PUT /warning-rules/{ruleId}
```

### 5.4 删除预警规则

```http
DELETE /warning-rules/{ruleId}
```

### 5.5 获取预警记录列表

```http
GET /families/{familyId}/warnings?status=PENDING&page=1&size=20
```

**查询参数**
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| status | String | 否 | 处理状态（PENDING/VIEWED/HANDLED/MEDICAL） |
| memberIds | String | 否 | 成员ID列表，逗号分隔 |
| startDate | String | 否 | 开始日期 |
| endDate | String | 否 | 结束日期 |
| page | Integer | 否 | 页码 |
| size | Integer | 否 | 每页条数 |

**响应**
```json
{
  "code": 200,
  "data": {
    "total": 10,
    "items": [
      {
        "id": "5001",
        "memberId": "2001",
        "memberName": "爸爸",
        "metricType": "BP_SYS",
        "metricName": "收缩压",
        "abnormalValue": "145",
        "warningLevel": "MEDIUM",
        "warningTime": "2026-01-29T08:00:00",
        "status": "PENDING",
        "remark": null
      }
    ]
  }
}
```

### 5.6 获取预警详情

```http
GET /warnings/{warningId}
```

### 5.7 更新预警处理状态

```http
PUT /warnings/{warningId}/status
```

**请求参数**
```json
{
  "status": "HANDLED",
  "remark": "已联系医生，建议调整用药"
}
```

### 5.8 预警统计分析

```http
GET /warnings/statistics?familyId=1001&period=30D
```

**响应**
```json
{
  "code": 200,
  "data": {
    "totalWarnings": 25,
    "pendingWarnings": 3,
    "handledWarnings": 20,
    "medicalWarnings": 2,
    "topWarnings": [
      { "metricType": "BP_SYS", "metricName": "收缩压", "count": 15 },
      { "metricType": "BG_FASTING", "metricName": "空腹血糖", "count": 8 }
    ],
    "memberRanking": [
      { "memberId": "2001", "memberName": "爸爸", "warningCount": 15 },
      { "memberId": "2002", "memberName": "妈妈", "warningCount": 10 }
    ]
  }
}
```

---

## 📖 健康内容模块 (Health Content)

### 6.1 获取推荐内容

```http
GET /health-contents/recommend?familyId=1001&page=1&size=10
```

**响应**
```json
{
  "code": 200,
  "data": {
    "items": [
      {
        "id": "6001",
        "contentType": "ACTIVITY",
        "title": "公园散步30分钟",
        "summary": "适合高血压老人的低强度运动",
        "coverImage": "https://cdn.example.com/activity1.jpg",
        "tags": ["高血压", "老人", "低强度"],
        "difficulty": "EASY",
        "duration": 30,
        "targetAudience": ["老人", "高血压"],
        "viewCount": 1000,
        "isFavorited": false
      }
    ]
  }
}
```

### 6.2 获取内容详情

```http
GET /health-contents/{contentId}
```

**响应**
```json
{
  "code": 200,
  "data": {
    "id": "6001",
    "contentType": "ACTIVITY",
    "title": "公园散步30分钟",
    "summary": "适合高血压老人的低强度运动",
    "content": "<p>详细活动说明...</p>",
    "coverImage": "https://cdn.example.com/activity1.jpg",
    "tags": ["高血压", "老人", "低强度"],
    "difficulty": "EASY",
    "duration": 30,
    "targetAudience": ["老人", "高血压"],
    "benefits": ["降低血压", "改善心肺功能"],
    "equipment": ["舒适的运动鞋"],
    "viewCount": 1000,
    "favoriteCount": 50,
    "isFavorited": false
  }
}
```

### 6.3 搜索内容

```http
GET /health-contents/search?keyword=高血压&type=ACTIVITY&page=1&size=20
```

### 6.4 收藏/取消收藏

```http
POST /health-contents/{contentId}/favorite
```

### 6.5 获取收藏列表

```http
GET /health-contents/favorites?page=1&size=20
```

---

## 🔌 设备模块 (Device)

### 7.1 扫描附近设备

```http
GET /devices/scan?deviceType=BP_MONITOR
```

**响应**
```json
{
  "code": 200,
  "data": {
    "devices": [
      {
        "deviceId": "OMRON_BP_001",
        "deviceName": "欧姆龙血压计",
        "brand": "OMRON",
        "model": "HEM-7121",
        "deviceType": "BP_MONITOR",
        "connectionType": "BLE",
        "rssi": -60,
        "isSupported": true
      }
    ]
  }
}
```

### 7.2 连接设备

```http
POST /devices/connect
```

**请求参数**
```json
{
  "deviceId": "OMRON_BP_001",
  "deviceType": "BP_MONITOR",
  "connectionType": "BLE"
}
```

### 7.3 获取已绑定设备列表

```http
GET /devices
```

**响应**
```json
{
  "code": 200,
  "data": {
    "items": [
      {
        "id": "7001",
        "deviceName": "欧姆龙血压计",
        "brand": "OMRON",
        "model": "HEM-7121",
        "deviceType": "BP_MONITOR",
        "nickname": "家用的",
        "memberId": "2001",
        "memberName": "爸爸",
        "lastSyncTime": "2026-01-29T08:00:00",
        "isActive": true
      }
    ]
  }
}
```

### 7.4 解除设备绑定

```http
DELETE /devices/{bindingId}
```

---

## 📔 健康日记模块 (Health Diary)

### 8.1 获取日记列表

```http
GET /members/{memberId}/diaries?page=1&size=20
```

### 8.2 创建日记

```http
POST /members/{memberId}/diaries
```

**请求参数**
```json
{
  "diaryDate": "2026-01-29",
  "content": "今天感觉不错，血压正常",
  "mood": "GOOD",
  "symptoms": [
    { "name": "头痛", "severity": "MILD" }
  ],
  "medication": [
    { "name": "降压药", "dosage": "1片", "frequency": "每日一次" }
  ],
  "images": ["https://cdn.example.com/image1.jpg"]
}
```

### 8.3 获取日记详情

```http
GET /diaries/{diaryId}
```

### 8.4 更新日记

```http
PUT /diaries/{diaryId}
```

### 8.5 删除日记

```http
DELETE /diaries/{diaryId}
```

---

## 🎯 家庭活动模块 (Family Activity)

### 9.1 获取家庭活动列表

```http
GET /families/{familyId}/activities?status=ACTIVE
```

**响应**
```json
{
  "code": 200,
  "data": {
    "items": [
      {
        "id": "8001",
        "familyId": "1001",
        "activityName": "每天步行8000步",
        "activityType": "STEPS",
        "targetValue": 8000,
        "unit": "步",
        "startDate": "2026-01-01",
        "endDate": null,
        "isRecurring": true,
        "recurringPattern": "DAILY",
        "status": "ACTIVE",
        "participantCount": 4
      }
    ]
  }
}
```

### 9.2 创建家庭活动

```http
POST /families/{familyId}/activities
```

**请求参数**
```json
{
  "activityName": "每天步行8000步",
  "activityType": "STEPS",
  "targetValue": 8000,
  "unit": "步",
  "startDate": "2026-01-01",
  "isRecurring": true,
  "recurringPattern": "DAILY"
}
```

### 9.3 打卡

```http
POST /activities/{activityId}/check-in
```

**请求参数**
```json
{
  "memberId": "2001",
  "actualValue": 10000,
  "note": "今天多走了几步",
  "images": ["https://cdn.example.com/screenshot.jpg"]
}
```

### 9.4 获取打卡记录

```http
GET /activities/{activityId}/check-ins?date=2026-01-29
```

---

## 📁 文件上传

### 10.1 获取上传凭证

```http
POST /files/upload-token
```

**请求参数**
```json
{
  "fileType": "IMAGE",
  "fileName": "avatar.jpg",
  "fileSize": 102400
}
```

**响应**
```json
{
  "code": 200,
  "data": {
    "uploadUrl": "https://oss.example.com/upload?token=...",
    "fileKey": "health/avatar/10001_1706496000.jpg",
    "expireIn": 3600
  }
}
```

---

*API文档由Swagger自动生成，如有变更请及时更新*
