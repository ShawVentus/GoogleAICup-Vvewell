# 整理范围

来源：`web-preview` 当前工作区（包含尚未提交的最新修改）；本目录不携带旧 Git 历史。原目录及线上服务未改动。

## 已收录

- Flutter `lib/assets/web/android/ios`、依赖清单与锁定文件、测试、资源生成工具、机器人调试工具、Markdown 文档。
- 两个本地蓝牙插件 `packages/alloop_blue_lite`、`packages/aizoring_blue_lite`，`hardware/` 和 `android_hardware_abstraction/`。
- 原生工程实际依赖的厂商 AAR/JAR/SO、rPPG ONNX 模型及配置；这些是运行依赖，并非构建缓存。
- 当前 Python Web 后端、医生推荐 v2 数据和提示词、仍被调用的旧推荐后端与旧目录数据。
- 数据库迁移、相关 SQL/HTTP 测试及维护脚本；构建、容器、部署脚本和配置模板。

## 排除

- 所有真实 `.env`、旧演示账户 `.enc`、签名凭据、个人 `local.properties`、生成的 iOS 配置。
- Git 历史、Flutter/Gradle/Python 缓存、Pods、构建后的网页、APK/IPA、日志、截图、ZIP 和本机工具链。
- `sample_data/` 中标注为真实佩戴数据的 CSV（未被 App 运行引用）；保留说明文档，App 原演示数据仍在源码和 assets 内。
- 重复的外层 Android checkout、独立 iOS 项目、旧独立医生前端、其他 Web 前端及未被此部署调用的独立后端。
- 重复的外层硬件抽象目录（同内容在 Flutter 项目内保留）、原始采集 `raw/`。
- `cloud_db/scripts/e2e_recommendation_api.py`：调用另一套本地 3100 端口服务，不属于此部署。

## 副本调整

仅禁用两个 `embedded_demo_*_credentials.dart` 内的旧 AES 解密密钥，保留加载 API；对应加密资产不收录。其余业务与硬件代码保留。构建说明改用本目录的相对路径，新增空配置模板及忽略规则。

此文件夹已整理，但尚未初始化新 Git 仓库、上传 GitHub 或重新部署。原生实机能力和厂商 SDK 公开再分发许可需要单独确认。

## 本次副本验证

- Web release 构建成功（`lib/main_web.dart`），公开构建产物凭据检查通过。
- 当前后端 27 项测试、兼容推荐后端 16 项测试、Flutter 预览 4 项及 OCR 3 项测试通过，共 50 项。
- 独立启动本目录后端：首页 HTTP 200、健康检查正常、878 名医生目录加载成功。
- 235 个插件、硬件和 Android 主工程文件与原工作区逐一比对一致。
- 已知私密配置值及常见凭据格式扫描未发现匹配项；旧嵌入密钥和账户包已排除。
- 验证生成的网页和缓存已移除；使用前运行构建脚本重新生成。未重新部署、未调用真实模型、未验证原生实机。

Android 构建适配：为满足当前 Flutter 3.47.3 的最低要求，副本主工程升级为 Gradle 8.14.3、AGP 8.13.2、Kotlin 2.2.20；原工作区不改动。
