# 家庭健康中心APP - 代码规范文档

> 最后更新时间：2026-01-29
> 适用范围：前端 (Flutter/Dart) + 后端 (Java/Spring Boot)
> 目的：统一代码风格，提高代码可读性和可维护性

---

## 📋 目录

1. [通用规范](#通用规范)
2. [Dart/Flutter 规范](#dartflutter-规范)
3. [Java/Spring Boot 规范](#javaspring-boot-规范)
4. [命名规范](#命名规范)
5. [注释规范](#注释规范)
6. [Git 提交规范](#git-提交规范)
7. [代码审查清单](#代码审查清单)

---

## 📐 通用规范

### 文件组织

```
项目根目录/
├── docs/               # 文档
├── database/           # 数据库脚本
├── flutter-app/        # Flutter前端项目
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app/       # 应用入口
│   │   ├── core/      # 核心功能
│   │   ├── data/      # 数据层
│   │   ├── domain/    # 领域层
│   │   ├── presentation/  # UI层
│   │   └── routes/    # 路由配置
│   ├── test/          # 测试
│   └── pubspec.yaml
└── spring-boot-backend/  # Spring Boot后端项目
    ├── src/main/java/com/health/
    │   ├── application/  # 应用层
    │   ├── domain/       # 领域层
    │   ├── infrastructure/  # 基础设施层
    │   └── interfaces/    # 接口层
    └── pom.xml
```

### 通用原则

| 原则 | 说明 |
|------|------|
| **KISS** | Keep It Simple, Stupid - 保持简单 |
| **DRY** | Don't Repeat Yourself - 避免重复代码 |
| **YAGNI** | You Aren't Gonna Need It - 不做不需要的功能 |
| **单一职责** | 每个类/函数只做一件事 |
| **开闭原则** | 对扩展开放，对修改关闭 |

---

## 🎯 Dart/Flutter 规范

### 1. 代码格式化

**使用 dart format 自动格式化**

```bash
# 格式化所有文件
dart format .

# 检查格式问题
dart format --output=none --set-exit-if-changed .
```

**行宽限制**: 80 字符

### 2. 命名规范

| 类型 | 规范 | 示例 |
|------|------|------|
| 类名 | 大驼峰 (PascalCase) | `class UserController {}` |
| 变量/方法 | 小驼峰 (camelCase) | `userName`, `getUserData()` |
| 常量 | 小驼峰 + 首字母小写 | `const maxCount = 100` |
| 私有成员 | 下划线前缀 | `var _privateValue` |
| 文件名 | 小写 + 下划线 | `user_service.dart` |

### 3. 类定义顺序

```dart
class UserService {
  // 1. 静态常量
  static const String baseUrl = 'https://api.example.com';

  // 2. 静态变量
  static String _token = '';

  // 3. 实例变量（public -> private）
  String name;
  int _age;

  // 4. 构造函数
  UserService({required this.name});

  // 5. Getters/Setters
  int get age => _age;

  // 6. 工厂构造函数
  factory UserService.fromJson(Map json) { ... }

  // 7. 公共方法
  void updateName(String newName) { ... }

  // 8. 私有方法
  void _validateName(String name) { ... }

  // 9. 重写方法
  @override
  String toString() => 'UserService(name: $name)';
}
```

### 4. Widget 组织

```dart
// 推荐方式：拆分小组件
class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('健康中心'),
    );
  }

  Widget _buildBody() {
    return ListView(
      children: [
        _buildHeader(),
        _buildContent(),
      ],
    );
  }

  Widget _buildHeader() => const HeaderWidget();
  Widget _buildContent() => const ContentWidget();
}
```

### 5. 状态管理 (GetX)

```dart
// Controller 定义
class UserController extends GetxController {
  // 使用 .obs 响应式变量
  var userList = <User>[].obs;
  var isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    isLoading.value = true;
    try {
      final users = await _userService.getUsers();
      userList.value = users;
    } catch (e) {
      // 错误处理
    } finally {
      isLoading.value = false;
    }
  }
}

// View 使用
class UserListView extends GetView<UserController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() => controller.isLoading.value
        ? const CircularProgressIndicator()
        : ListView.builder(
            itemCount: controller.userList.length,
            itemBuilder: (context, index) =>
                UserTile(user: controller.userList[index]),
          ));
  }
}
```

### 6. 异步处理

```dart
// 推荐：使用 async/await
Future<User> getUser(String id) async {
  try {
    final response = await _api.getUser(id);
    return User.fromJson(response.data);
  } catch (e) {
    _logger.e('获取用户失败: $e');
    rethrow;
  }
}

// 避免：使用 then
void badExample() {
  _api.getUser(id).then((user) {
    setState(() => _user = user);
  }).catchError((e) {
    print(e);
  });
}
```

### 7. 字符串处理

```dart
// 推荐：使用字符串插值
String greet(String name) => '你好, $name';

// 多行字符串
String longText = '''
  这是第一行
  这是第二行
  这是第三行
''';

// 原始字符串（不转义）
String raw = r'C:\Users\Documents';
```

### 8. 集合操作

```dart
// List 创建
final fruits = ['apple', 'banana', 'orange'];

// 推荐：使用 spread operator
final allFruits = ['kiwi', ...fruits];

// 推荐：使用 collection if
const showWarning = true;
final messages = [
  'Hello',
  if (showWarning) 'Warning',
];

// 推荐：使用 collection for
var nums = [1, 2, 3];
var doubled = [for (var n in nums) n * 2];
```

---

## ☕ Java/Spring Boot 规范

### 1. 代码格式化

**使用 Checkstyle + IDEA 自动格式化**

```xml
<!-- pom.xml 配置 -->
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-checkstyle-plugin</artifactId>
    <version>3.3.0</version>
    <configuration>
        <configLocation>checkstyle.xml</configLocation>
        <encoding>UTF-8</encoding>
        <consoleOutput>true</consoleOutput>
        <failsOnError>false</failsOnError>
    </configuration>
</plugin>
```

**格式化配置**
- 缩进：4 空格
- 行宽：120 字符
- 花括号：换行风格

### 2. 命名规范

| 类型 | 规范 | 示例 |
|------|------|------|
| 类名 | 大驼峰 (PascalCase) | `public class UserService {}` |
| 接口 | 大驼峰，可选I前缀 | `interface IUserDao {}` 或 `interface UserDao {}` |
| 方法/变量 | 小驼峰 (camelCase) | `String userName; void getUserData() {}` |
| 常量 | 全大写 + 下划线 | `public static final String MAX_COUNT = "100"` |
| 包名 | 全小写 + 点分隔 | `com.healthCenter.app.service` |

### 3. 类定义顺序

```java
public class UserService {
    // 1. 公共静态常量
    public static final String DEFAULT_AVATAR = "/default.png";

    // 2. 私有静态常量
    private static final Logger logger = LoggerFactory.getLogger(UserService.class);

    // 3. 依赖注入
    private final UserDao userDao;
    private final PasswordEncoder passwordEncoder;

    // 4. 公共实例变量（尽量少用）

    // 5. 私有实例变量
    private String currentUser;

    // 6. 构造函数
    public UserService(UserDao userDao, PasswordEncoder passwordEncoder) {
        this.userDao = userDao;
        this.passwordEncoder = passwordEncoder;
    }

    // 7. 公共方法（业务逻辑）
    public User getUserById(Long id) {
        return userDao.findById(id)
                .orElseThrow(() -> new UserNotFoundException(id));
    }

    // 8. 私有方法
    private void validateUser(User user) {
        if (user.getName() == null) {
            throw new ValidationException("用户名不能为空");
        }
    }

    // 9. Getter/Setter（使用 Lombok 简化）
    // 10. 重写方法（equals, hashCode, toString）
}
```

### 4. 注解使用

```java
// Controller 层
@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
@Tag(name = "用户管理", description = "用户相关接口")
public class UserController {

    private final UserService userService;

    @GetMapping("/{id}")
    @Operation(summary = "获取用户详情")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "成功"),
        @ApiResponse(responseCode = "404", description = "用户不存在")
    })
    public ResponseEntity<UserVO> getUser(
            @PathVariable Long id,
            @RequestHeader("Authorization") String token) {
        UserVO user = userService.getUserById(id);
        return ResponseEntity.ok(user);
    }

    @PostMapping
    @Operation(summary = "创建用户")
    public ResponseEntity<UserVO> createUser(
            @Valid @RequestBody UserCreateRequest request) {
        UserVO user = userService.createUser(request);
        return ResponseEntity.status(201).body(user);
    }
}

// Service 层
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class UserService {

    private final UserDao userDao;
    private final PasswordEncoder passwordEncoder;

    @Transactional
    public UserVO createUser(UserCreateRequest request) {
        // 业务逻辑
        User user = new User();
        user.setName(request.getName());
        user.setPassword(passwordEncoder.encode(request.getPassword()));
        userDao.save(user);
        return UserVO.fromEntity(user);
    }
}

// Dao 层（MyBatis-Plus）
@Mapper
public interface UserDao extends BaseMapper<User> {

    @Select("SELECT * FROM user WHERE phone = #{phone}")
    Optional<User> findByPhone(@Param("phone") String phone);
}
```

### 5. 异常处理

```java
// 自定义业务异常
public class BusinessException extends RuntimeException {
    private final String code;

    public BusinessException(String code, String message) {
        super(message);
        this.code = code;
    }
}

// 全局异常处理
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ErrorResponse> handleBusinessException(BusinessException e) {
        log.error("业务异常: {}", e.getMessage());
        return ResponseEntity.status(400)
                .body(new ErrorResponse(e.getCode(), e.getMessage()));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleException(Exception e) {
        log.error("系统异常", e);
        return ResponseEntity.status(500)
                .body(new ErrorResponse("500", "系统内部错误"));
    }
}
```

### 6. 日志规范

```java
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class UserService {
    private static final Logger logger = LoggerFactory.getLogger(UserService.class);

    public void createUser(UserRequest request) {
        logger.debug("创建用户, 请求参数: {}", request);

        try {
            // 业务逻辑
            logger.info("用户创建成功, userId: {}", user.getId());
        } catch (Exception e) {
            logger.error("用户创建失败, phone: {}", request.getPhone(), e);
            throw e;
        }
    }
}

// 日志级别使用规范
logger.trace("详细调试信息");   // 最详细，生产环境关闭
logger.debug("调试信息");        // 开发调试
logger.info("关键业务信息");     // 重要业务节点
logger.warn("警告信息");         // 可能有问题但不影响运行
logger.error("错误信息");        // 错误异常，需关注
```

### 7. 数据库操作

```java
// 使用 MyBatis-Plus
@Service
@RequiredArgsConstructor
public class HealthDataService {

    private final HealthDataDao healthDataDao;

    // 查询示例
    public List<HealthData> getMemberData(Long memberId, LocalDate startDate, LocalDate endDate) {
        return healthDataDao.lambdaQuery()
                .eq(HealthData::getMemberId, memberId)
                .between(HealthData::getRecordTime, startDate, endDate)
                .orderByDesc(HealthData::getRecordTime)
                .list();
    }

    // 分页查询
    public Page<HealthData> getMemberDataPage(Long memberId, int page, int size) {
        return healthDataDao.lambdaQuery()
                .eq(HealthData::getMemberId, memberId)
                .orderByDesc(HealthData::getRecordTime)
                .page(new Page<>(page, size));
    }

    // 事务操作
    @Transactional(rollbackFor = Exception.class)
    public void saveHealthData(HealthDataRequest request) {
        // 保存数据
        HealthData data = new HealthData();
        // ... 设置字段
        healthDataDao.save(data);

        // 触发预警检查
        warningService.checkAndCreateWarning(data);
    }
}
```

### 8. 配置文件规范

```yaml
# application-{profile}.yml
spring:
  application:
    name: health-center-backend
  profiles:
    active: ${SPRING_PROFILE:dev}

  # 数据源配置
  datasource:
    url: jdbc:mysql://${DB_HOST:localhost}:${DB_PORT:3306}/${DB_NAME:health_center_db}?useSSL=false&serverTimezone=Asia/Shanghai
    username: ${DB_USERNAME:root}
    password: <已打码：请用环境变量注入，勿写入仓库>
    driver-class-name: com.mysql.cj.jdbc.Driver
    hikari:
      maximum-pool-size: 20
      minimum-idle: 5
      connection-timeout: 30000

  # Redis 配置
  redis:
    host: ${REDIS_HOST:localhost}
    port: ${REDIS_PORT:6379}
    password: <已打码：请用环境变量注入，勿写入仓库>
    database: ${REDIS_DB:0}
    lettuce:
      pool:
        max-active: 20
        max-idle: 10
        min-idle: 5

  # RabbitMQ 配置
  rabbitmq:
    host: ${RABBITMQ_HOST:localhost}
    port: ${RABBITMQ_PORT:5672}
    username: ${RABBITMQ_USERNAME:guest}
    password: <已打码：请用环境变量注入，勿写入仓库>

# 服务器配置
server:
  port: ${SERVER_PORT:8080}
  servlet:
    context-path: /api/v1

# 日志配置
logging:
  level:
    root: INFO
    com.health: ${LOG_LEVEL:DEBUG}
  pattern:
    console: "%d{yyyy-MM-dd HH:mm:ss} [%thread] %-5level %logger{36} - %msg%n"
```

---

## 📝 命名规范

### 通用命名原则

1. **见名知意**：名称应该清楚表达其用途
2. **避免缩写**：除非是通用缩写（如 Id, Url, Http）
3. **避免拼音**：不使用拼音命名
4. **一致性**：同类概念使用相同术语

### 数据库命名规范

| 类型 | 规范 | 示例 |
|------|------|------|
| 表名 | 小写 + 下划线 | `user`, `family_member`, `health_data` |
| 字段名 | 小写 + 下划线 | `user_id`, `create_time`, `is_deleted` |
| 索引名 | `idx_` + 表名 + 字段 | `idx_user_phone` |
| 唯一索引 | `uk_` + 表名 + 字段 | `uk_user_phone` |
| 外键名 | `fk_` + 表名 + 字段 | `fk_member_family` |
| 主键名 | `pk_` + 表名 | `pk_user` |

### API 命名规范

```
GET    /api/v1/users              # 获取用户列表
GET    /api/v1/users/{id}         # 获取用户详情
POST   /api/v1/users              # 创建用户
PUT    /api/v1/users/{id}         # 更新用户
DELETE /api/v1/users/{id}         # 删除用户
PATCH  /api/v1/users/{id}/status  # 部分更新

# 复杂查询使用查询参数
GET /api/v1/users?page=1&size=20&status=ACTIVE
GET /api/v1/users?startDate=2026-01-01&endDate=2026-01-31

# 资源嵌套
GET /api/v1/families/{id}/members
POST /api/v1/families/{id}/members
```

---

## 💬 注释规范

### Java 注释

```java
/**
 * 用户服务类
 *
 * <p>负责用户相关的业务逻辑处理，包括用户创建、查询、更新、删除等操作。</p>
 *
 * @author 开发团队
 * @since 1.0.0
 */
@Service
public class UserService {

    /**
     * 根据用户ID获取用户信息
     *
     * @param userId 用户ID，不能为空
     * @return 用户信息，如果用户不存在则抛出异常
     * @throws UserNotFoundException 当用户不存在时抛出
     */
    public User getUserById(Long userId) {
        // 实现
    }

    // 单行注释：解释复杂逻辑
    // 使用三步校验：1.格式校验 2.业务校验 3.权限校验
    private void validateUser(User user) {
        // 实现
    }
}
```

### Dart 注释

```dart
/// 用户服务类
///
/// 负责用户相关的业务逻辑处理。
class UserService {
  /// 根据用户ID获取用户信息
  ///
  /// [userId] 用户ID，不能为空
  ///
  /// 返回用户信息，如果用户不存在则抛出异常
  Future<User> getUserById(String userId) async {
    // 实现
  }

  // 单行注释：解释复杂逻辑
  void _validateUser(User user) {
    // 实现
  }
}
```

### 注释原则

| 应该注释 | 不应注释 |
|----------|----------|
| 复杂的业务逻辑 | 明显的代码 |
| 算法的核心思想 | 简单的 getter/setter |
| 为什么这样做 | 做了什么 |
| 已知的问题/TODO | 版本控制信息 |
| 公共 API 文档 | 重复代码逻辑的注释 |

---

## 🔄 Git 提交规范

### Commit Message 格式

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Type 类型

| 类型 | 说明 |
|------|------|
| `feat` | 新功能 |
| `fix` | 修复 Bug |
| `docs` | 文档更新 |
| `style` | 代码格式调整（不影响逻辑） |
| `refactor` | 代码重构（不改变功能） |
| `test` | 测试相关 |
| `chore` | 构建/工具配置等 |
| `perf` | 性能优化 |

### 示例

```bash
# 简单提交
feat(auth): 添加用户注册功能

# 带说明的提交
fix(member): 修复成员删除时的外键约束错误

删除成员时没有先删除关联的健康数据，导致外键约束错误。
现在改为先删除关联数据再删除成员。

Closes #123

# 文档提交
docs(api): 更新用户接口文档

# 重构
refactor(user): 重构用户服务层代码结构

将用户相关操作从 UserService 拆分为 UserService 和 UserAuthService
```

### 分支命名规范

```
main           # 主分支，生产环境代码
develop        # 开发分支
feature/xxx    # 功能分支: feature/login, feature/health-data
bugfix/xxx     # 修复分支: bugfix/member-delete-error
hotfix/xxx     # 紧急修复: hotfix/security-patch
release/x.x.x  # 发布分支: release/1.0.0
```

---

## ✅ 代码审查清单

### 提交代码前自查

- [ ] 代码已格式化（`dart format` / IDEA Reformat）
- [ ] 代码无警告（`flutter analyze` / Checkstyle）
- [ ] 测试通过（`flutter test` / `mvn test`）
- [ ] 注释充分，特别是复杂逻辑
- [ ] 没有调试代码（console.log / System.out.println）
- [ ] 没有注释掉的代码
- [ ] 敏感信息已移除（密码、密钥等）
- [ ] Commit Message 符合规范

### 代码审查要点

| 检查项 | 说明 |
|--------|------|
| **功能正确性** | 代码是否实现了预期功能 |
| **代码风格** | 是否符合团队代码规范 |
| **错误处理** | 是否有适当的异常处理 |
| **性能影响** | 是否有明显的性能问题 |
| **安全性** | 是否有安全漏洞（SQL注入、XSS等） |
| **测试覆盖** | 是否有足够的单元测试 |
| **可维护性** | 代码是否易于理解和维护 |

---

## 📚 参考资源

| 资源 | 链接 |
|------|------|
| Dart 语言规范 | https://dart.dev/guides/language/effective-dart |
| Flutter 风格指南 | https://flutter.dev/docs/development/data-and-backend/state-mgmt/options |
| Java 代码规范 | https://google.github.io/styleguide/javaguide.html |
| Spring Boot 最佳实践 | https://spring.io/guides |
| RESTful API 设计指南 | https://restfulapi.net/ |

---

*代码规范是团队协作的基础，请严格遵守。如有建议或疑问，请联系技术负责人*
