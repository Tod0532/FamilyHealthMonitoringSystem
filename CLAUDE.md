# 家庭健康中心 APP

## 技术栈
- **前端**: Flutter 3.24.5 + GetX 状态管理 + fl_chart + ScreenUtil
- **后端**: Spring Boot 2.7 + MyBatis Plus + MySQL + JWT
- **AI模型**: MobileNetV2 + TFLite (血压计LCD识别)

## 编译要点
- **Java版本**: 必须使用 Java 17（非21），在 `android/gradle.properties` 配置 `org.gradle.java.home`
- **国内镜像**: 已配置 Flutter/Maven 阿里云镜像
- **编译命令**: `flutter build apk --debug` / `flutter build apk --release`
- **构建产物**: `build/app/outputs/flutter-apk/app-*.apk`

## 关键文档
- `docs/coding-standards.md` - 代码规范（命名、注释、Git提交）
- `docs/build-troubleshooting.md` - 编译问题及解决方案
- `docs/planTask.md` - 项目进度跟踪
- `flutter-app/APP_DESIGN.md` - UI设计规范

## 文档更新规则
- 代码修改后必须运行 `python scripts/update_docs.py --type <类型> --scope <范围> --desc <描述> --files <文件>`
- 类型: feat/fix/refactor/test/docs/style/chore
- 范围: UI界面/API接口/数据库/数据仓储/数据模型/依赖注入/工具类/通用

## 项目结构
```
flutter-app/lib/
├── app/modules/    # 功能模块（GetX模式）
├── app/routes/     # 路由配置
├── core/           # 核心功能（models/storage/network/bluetooth）
└── main.dart
```

## AI/OCR 脚本
- `flutter-app/analyze_*.py` - LCD识别训练脚本
- `flutter-app/assets/models/` - TFLite模型存放
- `flutter-app/dataset/` - 训练数据集