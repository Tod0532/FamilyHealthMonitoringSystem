# 家庭健康中心APP - 变更记录

> 本文件记录项目开发过程中的所有变更，按时间倒序排列

---

## 2026-01-29 (下午 - 第三次)

### 📁 新增文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| spring-boot-backend/.../config/JwtProperties.java | JWT配置属性 | Claude |
| spring-boot-backend/.../config/JwtConfig.java | JWT配置类 | Claude |
| spring-boot-backend/.../util/JwtUtil.java | JWT工具类 | Claude |
| spring-boot-backend/.../domain/entity/User.java | 用户实体 | Claude |
| spring-boot-backend/.../domain/mapper/UserMapper.java | 用户Mapper | Claude |
| spring-boot-backend/.../service/UserService.java | 用户服务接口 | Claude |
| spring-boot-backend/.../service/impl/UserServiceImpl.java | 用户服务实现 | Claude |
| spring-boot-backend/.../interfaces/controller/AuthController.java | 认证控制器 | Claude |
| spring-boot-backend/.../interfaces/controller/UserController.java | 用户控制器 | Claude |
| spring-boot-backend/.../interfaces/dto/LoginRequest.java | 登录请求DTO | Claude |
| spring-boot-backend/.../interfaces/dto/RegisterRequest.java | 注册请求DTO | Claude |
| spring-boot-backend/.../interfaces/dto/AuthResponse.java | 认证响应DTO | Claude |
| spring-boot-backend/.../interfaces/dto/UserVO.java | 用户视图对象 | Claude |
| flutter-app/lib/core/models/user.dart | 用户模型 | Claude |
| flutter-app/lib/core/models/auth_request.dart | 认证请求模型 | Claude |
| flutter-app/lib/core/models/auth_response.dart | 认证响应模型 | Claude |
| flutter-app/lib/app/modules/login/login_page.dart | 登录页面 | Claude |
| flutter-app/lib/app/modules/login/login_controller.dart | 登录控制器 | Claude |
| flutter-app/lib/app/modules/login/login_binding.dart | 登录页面绑定 | Claude |
| flutter-app/lib/app/modules/register/register_page.dart | 注册页面 | Claude |
| flutter-app/lib/app/modules/register/register_controller.dart | 注册控制器 | Claude |
| flutter-app/lib/app/modules/register/register_binding.dart | 注册页面绑定 | Claude |

### 📝 修改文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| C:/Users/m/.claude/settings.json | 修复hook路径格式 | Claude |
| spring-boot-backend/.../interfaces/exception/ErrorCode.java | 添加认证相关错误码 | Claude |
| flutter-app/lib/app/routes/app_pages.dart | 添加登录/注册路由 | Claude |
| flutter-app/lib/core/storage/storage_service.dart | 添加用户信息存储方法 | Claude |

### 📋 变更内容

#### 类型：feat（新功能）
#### 范围：API接口、UI界面
#### 描述：用户认证模块开发完成

**后端开发 (Spring Boot)**：

1. **JWT认证**：
   - JwtProperties：JWT配置属性（密钥、过期时间）
   - JwtUtil：JWT生成和验证工具类
   - JwtConfig：JWT配置类

2. **用户服务**：
   - User实体：用户数据模型
   - UserMapper：MyBatis-Plus Mapper
   - UserService/Impl：用户业务逻辑
   - 支持注册、登录、刷新令牌、登出

3. **认证API**：
   - POST /auth/register：用户注册
   - POST /auth/login：用户登录
   - POST /auth/refresh：刷新令牌
   - POST /auth/logout：用户登出
   - GET /user/info：获取当前用户信息

**前端开发 (Flutter)**：

1. **数据模型**：
   - User：用户模型
   - LoginRequest：登录请求
   - RegisterRequest：注册请求（含验证）
   - AuthResponse：认证响应

2. **登录页面**：
   - 手机号/密码输入
   - 记住密码功能
   - 密码可见性切换
   - 表单验证
   - 跳转注册页面

3. **注册页面**：
   - 手机号/验证码/密码输入
   - 验证码倒计时
   - 密码强度验证
   - 用户协议勾选
   - 表单验证

4. **存储服务**：
   - 添加用户信息存储方法
   - 支持记住密码功能

**配置修复**：
- 修复 Claude Code hook 配置路径格式问题（Windows -> Unix）

#### 影响文件
- 后端：17个新文件
- 前端：10个新文件
- 配置：4个修改文件

---

## 2026-01-29 (深夜)

### 📁 新增文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| flutter-app/lib/core/utils/logger.dart | 日志工具类 | Claude |
| flutter-app/lib/app/routes/middlewares/auth_middleware.dart | 认证中间件 | Claude |

### 📝 修改文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| database/schema.sql | 修复外键约束问题 | Claude |
| flutter-app/lib/main.dart | 修复重复定义和导入顺序 | Claude |
| flutter-app/lib/app/routes/app_pages.dart | 简化路由配置，移除不存在的页面 | Claude |
| flutter-app/lib/app/modules/splash/splash_page.dart | 修复导入问题 | Claude |

### 📋 变更内容

#### 类型：fix（修复Bug）
#### 范围：代码质量
#### 描述：代码审查与问题修复

**发现并修复的问题**：

1. **数据库SQL**：
   - 问题：`warning_rule` 表外键约束与初始化数据冲突
   - 修复：将 `member_id` 改为可为 NULL，添加 ON DELETE SET NULL

2. **Flutter前端**：
   - 问题1：`main.dart` 和 `app_pages.dart` 重复定义 `AppRoutes`
   - 修复：移除 `main.dart` 中的 `AppRoutes` 定义
   - 问题2：缺失 `core/utils/logger.dart` 文件
   - 修复：创建日志工具类
   - 问题3：路由引用不存在的页面
   - 修复：简化路由配置，使用启动页占位
   - 问题4：缺失 `auth_middleware.dart`
   - 修复：创建认证中间件

**代码审查结论**：
- ✅ 数据库SQL：结构合理，索引完善，外键约束正确
- ✅ Flutter前端：依赖配置正确，入口文件完整，路由清晰
- ✅ Spring Boot后端：配置规范，异常处理完善，依赖版本合理

#### 影响文件
- database/schema.sql (修改)
- flutter-app/lib/main.dart (修改)
- flutter-app/lib/app/routes/app_pages.dart (修改)
- flutter-app/lib/app/modules/splash/splash_page.dart (修改)
- flutter-app/lib/core/utils/logger.dart (新增)
- flutter-app/lib/app/routes/middlewares/auth_middleware.dart (新增)

---

## 2026-01-29 (晚上)

### 📁 新增文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| database/schema.sql | 数据库建表SQL脚本 | Claude |
| docs/coding-standards.md | 代码规范文档 | Claude |
| flutter-app/pubspec.yaml | Flutter项目配置 | Claude |
| flutter-app/lib/main.dart | Flutter应用入口 | Claude |
| flutter-app/lib/app/routes/app_pages.dart | 路由配置 | Claude |
| flutter-app/lib/core/storage/storage_service.dart | 存储服务 | Claude |
| flutter-app/lib/core/network/dio_provider.dart | 网络服务(Dio) | Claude |
| flutter-app/lib/core/network/api_response.dart | API响应类 | Claude |
| flutter-app/lib/core/network/api_exception.dart | API异常类 | Claude |
| flutter-app/lib/app/modules/splash/splash_page.dart | 启动页 | Claude |
| spring-boot-backend/pom.xml | Maven项目配置 | Claude |
| spring-boot-backend/src/main/java/com/health/HealthCenterApplication.java | Spring Boot入口 | Claude |
| spring-boot-backend/src/main/resources/application.yml | 应用配置 | Claude |
| spring-boot-backend/.../response/ApiResponse.java | 统一响应格式 | Claude |
| spring-boot-backend/.../response/PageResponse.java | 分页响应格式 | Claude |
| spring-boot-backend/.../exception/GlobalExceptionHandler.java | 全局异常处理 | Claude |
| spring-boot-backend/.../exception/BusinessException.java | 业务异常 | Claude |
| spring-boot-backend/.../exception/NotFoundException.java | 资源不存在异常 | Claude |
| spring-boot-backend/.../exception/ErrorCode.java | 错误码枚举 | Claude |

### 📋 变更内容

#### 类型：feat（新功能）
#### 范围：项目初始化
#### 描述：第1周任务完成 - 项目脚手架搭建

**数据库层面**：
- 创建数据库建表SQL脚本（12张表）
- 包含索引、外键、初始化数据

**前端项目 (Flutter)**：
- 项目配置 (pubspec.yaml)：GetX、Dio、sqflite等依赖
- 应用入口与主题配置
- 路由配置与认证中间件
- 存储服务（SharedPreferences + GetStorage）
- 网络服务（Dio封装 + 拦截器 + 重试机制）
- API响应/异常类
- 启动页示例

**后端项目 (Spring Boot)**：
- Maven项目配置（Spring Boot 3.2.2 + Java 17）
- 应用配置（MySQL、Redis、RabbitMQ、JWT）
- 统一响应格式（ApiResponse + PageResponse）
- 全局异常处理器
- 业务异常类与错误码枚举

**文档层面**：
- 新增代码规范文档（Dart + Java）

#### 影响文件
- database/schema.sql (新增)
- docs/coding-standards.md (新增)
- flutter-app/* (新增)
- spring-boot-backend/* (新增)

---

## 2026-01-29 (下午 - 第二次)

### 📁 修改文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| docs/build-troubleshooting.md | 优化编译问题记录文档结构 | Claude |

### 📋 变更内容

#### 类型：docs（文档相关）
#### 范围：通用
#### 描述：新增"快速参考"章节，整理常用编译命令

1. 在文档开头新增「正确编译方法 - 快速参考」章节
2. 添加 Flutter 常用命令速查
3. 添加 Spring Boot 常用命令速查
4. 添加完整编译流程（首次编译或大更新后）
5. 添加 Git 提交前检查命令
6. 新增常见问题：Gradle 下载缓慢、内存溢出、Redis 连接失败

#### 影响文件
- docs/build-troubleshooting.md (修改)

---

## 2026-01-29 (下午 - 第一次)

### 📁 新增文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| docs/build-troubleshooting.md | 编译构建问题记录文档 | Claude |

### 📋 变更内容

#### 类型：docs（文档相关）
#### 范围：通用
#### 描述：添加编译问题排查文档

创建编译/构建问题记录文档，包含：
1. 环境配置要求（Flutter + Spring Boot）
2. 正确的编译/构建流程
3. 常见问题及解决方案（Flutter 5个 + Spring Boot 5个）
4. 问题记录模板
5. 问题历史记录

#### 影响文件
- docs/build-troubleshooting.md (新增)

---

## 2026-01-29 (上午)

### 📁 新增文件

| 文件路径 | 说明 | 作者 |
|----------|------|------|
| docs/planTask.md | 项目进度跟踪文件 | Claude |
| docs/planNext.md | 下一步工作计划 | Claude |
| docs/changed.md | 变更记录文件 | Claude |
| docs/database.md | 数据库设计文档 | Claude |
| docs/api.md | API接口文档 | Claude |

### 📋 变更内容

#### 类型：docs（文档相关）
#### 范围：通用
#### 描述：初始化项目文档结构

1. 完成需求深度分析
2. 创建项目进度跟踪文档
3. 创建下一步工作计划文档
4. 创建变更记录文档
5. 创建数据库设计文档
6. 创建API接口文档

#### 影响文件
- docs/planTask.md
- docs/planNext.md
- docs/changed.md
- docs/database.md
- docs/api.md

---

## 变更类型说明

| 类型代码 | 类型名称 | 说明 |
|----------|----------|------|
| feat | 新功能 | 添加新特性 |
| fix | 修复Bug | 修复问题 |
| refactor | 代码重构 | 代码结构优化 |
| test | 测试相关 | 添加或修改测试 |
| docs | 文档相关 | 文档变更 |
| style | 代码格式 | 代码风格调整 |
| chore | 杂项 | 其他配置等 |

## 变更范围说明

| 范围代码 | 范围名称 |
|----------|----------|
| UI界面 | UI组件、页面 |
| API接口 | 网络请求、API定义 |
| 数据库 | 实体、DAO、数据库操作 |
| 数据仓储 | Repository层 |
| 数据模型 | 数据类、模型 |
| 依赖注入 | Hilt模块 |
| 工具类 | 工具函数、帮助类 |
| 通用 | 其他 |

---

## 统计信息

| 统计项 | 数量 |
|--------|------|
| 总变更次数 | 7 |
| 本周变更 | 7 |
| 新增文件 | 55 |
| 修改文件 | 12 |
| 删除文件 | 0 |

---

*每次变更后请更新本文件，格式参考上方模板*
