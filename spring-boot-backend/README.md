# 家庭健康中心APP - 后端服务

基于 Spring Boot 3.2 + MyBatis-Plus + JWT 的家庭健康数据管理后端服务。

## 技术栈

| 技术 | 版本 | 说明 |
|------|------|------|
| Spring Boot | 3.2.2 | 基础框架 |
| JDK | 17 | 运行环境 |
| MyBatis-Plus | 3.5.5 | ORM框架 |
| MySQL | 8.0+ | 数据库 |
| Redis | 7.0+ | 缓存/会话 |
| Spring Security | 6.x | 安全框架 |
| JWT | 0.12.3 | 令牌认证 |
| Knife4j | 4.4.0 | API文档 |

## 项目结构

```
spring-boot-backend/
├── src/main/java/com/health/
│   ├── config/          # 配置类
│   ├── domain/          # 领域模型
│   │   ├── entity/      # 实体类
│   │   └── mapper/      # MyBatis Mapper
│   ├── exception/       # 异常处理
│   ├── filter/          # 过滤器
│   ├── interfaces/      # 接口层
│   │   ├── controller/  # REST控制器
│   │   ├── dto/         # 数据传输对象
│   │   ├── response/    # 响应对象
│   │   └── vo/          # 视图对象
│   ├── service/         # 服务层
│   ├── util/            # 工具类
│   └── HealthCenterApplication.java
└── src/main/resources/
    ├── application.yml  # 配置文件
    └── db/              # 数据库脚本
```

## 快速开始

### 1. 环境准备

- JDK 17+
- Maven 3.8+
- MySQL 8.0+
- Redis 7.0+

### 2. 数据库初始化

```bash
# 登录MySQL
mysql -u root -p

# 执行初始化脚本
source src/main/resources/db/schema.sql
```

### 3. 配置文件修改

编辑 `application.yml`，修改数据库和Redis连接信息：

```yaml
spring:
  datasource:
    url: jdbc:mysql://localhost:3306/health_center_db
    username: root
    password: your_password
  data:
    redis:
      host: localhost
      port: 6379
```

### 4. 启动服务

```bash
# 编译打包
mvn clean package -DskipTests

# 运行服务
java -jar target/health-center-backend-1.0.0.jar

# 或直接使用Maven插件运行
mvn spring-boot:run
```

### 5. 访问API文档

服务启动后，访问 Knife4j 文档：

```
http://localhost:8080/api/v1/doc.html
```

## API端点

### 认证管理

| 端点 | 方法 | 描述 | 认证 |
|------|------|------|------|
| /auth/register | POST | 用户注册 | 否 |
| /auth/login | POST | 用户登录 | 否 |
| /auth/refresh | POST | 刷新令牌 | 否 |
| /auth/logout | POST | 用户登出 | 是 |

### 家庭成员管理

| 端点 | 方法 | 描述 | 认证 |
|------|------|------|------|
| /api/members | GET | 获取成员列表 | 是 |
| /api/members | POST | 添加成员 | 是 |
| /api/members/{id} | PUT | 更新成员 | 是 |
| /api/members/{id} | DELETE | 删除成员 | 是 |

### 健康数据管理

| 端点 | 方法 | 描述 | 认证 |
|------|------|------|------|
| /api/health-data | GET | 获取数据列表 | 是 |
| /api/health-data | POST | 添加数据 | 是 |
| /api/health-data/{id} | PUT | 更新数据 | 是 |
| /api/health-data/{id} | DELETE | 删除数据 | 是 |
| /api/health-data/stats | GET | 获取统计 | 是 |
| /api/health-data/trend | GET | 获取趋势 | 是 |

### 预警规则管理

| 端点 | 方法 | 描述 | 认证 |
|------|------|------|------|
| /api/alert-rules | GET | 获取规则列表 | 是 |
| /api/alert-rules | POST | 添加规则 | 是 |
| /api/alert-rules/{id} | PUT | 更新规则 | 是 |
| /api/alert-rules/{id} | DELETE | 删除规则 | 是 |

### 预警记录管理

| 端点 | 方法 | 描述 | 认证 |
|------|------|------|------|
| /api/alert-records | GET | 获取记录列表 | 是 |
| /api/alert-records/unread-count | GET | 获取未读数 | 是 |
| /api/alert-records/{id}/read | PUT | 标记已读 | 是 |

## 测试账号

```
手机号: 13800138000
密码: 123456
```

## 环境变量

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| SERVER_PORT | 服务端口 | 8080 |
| DB_HOST | 数据库主机 | localhost |
| DB_PORT | 数据库端口 | 3306 |
| DB_NAME | 数据库名称 | health_center_db |
| DB_USERNAME | 数据库用户名 | root |
| DB_PASSWORD | 数据库密码 | - |
| REDIS_HOST | Redis主机 | localhost |
| REDIS_PORT | Redis端口 | 6379 |
| JWT_SECRET | JWT密钥 | - |
| JWT_EXPIRATION | 令牌有效期(秒) | 86400 |

## 开发说明

### 数据类型

健康数据支持以下类型：

| 类型标识 | 名称 | 单位 | value1 | value2 |
|---------|------|------|--------|--------|
| blood_pressure | 血压 | mmHg | 收缩压 | 舒张压 |
| heart_rate | 心率 | 次/分 | 心率值 | - |
| blood_sugar | 血糖 | mmol/L | 血糖值 | - |
| temperature | 体温 | ℃ | 体温值 | - |
| weight | 体重 | kg | 体重值 | - |
| height | 身高 | cm | 身高值 | - |
| steps | 步数 | 步 | 步数 | - |
| sleep | 睡眠 | 小时 | 时长 | - |

### 预警级别

- `info`: 信息提示
- `warning`: 警告
- `danger`: 危险

### 预警条件

- `gt`: 大于
- `lt`: 小于
- `eq`: 等于
- `between`: 区间（between threshold1 and threshold2）
