# Android 模拟器构建 — 工程交接

- 更新时间：2026-10-18 11:17 PDT
- 工作目录：`/Users/mac/dev/vvewell-physicalAI/github-upload`
- 原始工作区：`/Users/mac/dev/vvewell-physicalAI/web-preview`，分支 `codex/web-preview`，基线 `1c695ed`
- 当前目录尚未初始化 Git，也未上传 GitHub。

## 目标与当前结论

用户要构建包含“找医生”的融合版 Android App，并在模拟器里查看。**已完成 APK 构建、覆盖安装和启动；已观察到 Find a doctor 页面收到在线后端的真实追问回复。** 模拟器 `vvewell_api36_arm64` 在线，设备 ID 为 `emulator-5554`。

## 本次接手结果

- 修复 `lib/features/main/home_page.dart` 中三个仅限 Web 的入口/页面限制：Android 首页也显示 Find a doctor，对话页包含医生标签和同一个医生对话组件；默认选中医生工作区。其他咨询主题仍保留。
- 构建时必须通过 Dart define 指定 `DOCTOR_API_BASE=https://vvewell-web-preview-357361255240.asia-east1.run.app`。手机端不能使用浏览器同源默认地址。
- 后端 `/api/health` 返回 `status=ok`、`doctor_version=2`、`doctor_count=878`。
- 最新构建日志：`/tmp/vvewell-upload-gradle-doctor.log`，`BUILD SUCCESSFUL in 1m 15s`。
- APK：`alloop-SDK/build/app/outputs/apk/debug/vvewell_1.0.9_20261019.apk`（文件名日期由构建脚本生成）。
- `adb install -r` 返回 Success，保留模拟器原有 App 数据；`am start -W` 返回 Status: ok，前台为 `com.alloop.blue.test/.MainActivity`。
- 已确认首页、对话标签及医生回复实际显示；截图 `/tmp/vvewell-android-doctor.png`。
- 原生入口切换回归测试 `test/doctor_native_integration_test.dart` 1 项通过；Chrome 的 `test/chat_workspace_browser_test.dart` 2 项通过。
- 本次首次打包虽成功但缺少 `kernel_blob.bin`，运行黑屏。清单混用 build 符号链接与外置盘真实路径。追加本机临时脚本 `/tmp/vvewell-canonical-build.gradle` 统一 Gradle buildDirectory 为 canonicalFile 后已解决。必须保留下面两个 init-script 参数；不能只依赖 BUILD SUCCESSFUL，需检查 APK 的启动资源。
- 以下失败记录保留为历史。

## 此前已确认

- 整理目录里的 Web 后端测试、医生推荐兼容测试及两组 Flutter 测试此前共 50 项通过；Web 独立构建与本地后端启动也曾通过。这些结果不代表 Android 包构建成功。
- Android Dart 部分、Android/Kotlin 代码、蓝牙与雷达模块已在当前 APK 构建尝试中通过编译；构建失败在 `:app:mergeDebugNativeLibs`，明确报错为 `No space left on device`。该次 APK 尚未出现；本次已成功生成。
- 第一次 Android 构建还发现 Gradle 版本低于当前 Flutter 最低要求；已仅修改本整理副本的构建版本：Gradle 8.11.1 → 8.14.3、AGP 8.9.1 → 8.13.2、Kotlin 2.1.0 → 2.2.20。对应文件：
  - `alloop-SDK/android/gradle/wrapper/gradle-wrapper.properties`
  - `alloop-SDK/android/settings.gradle.kts`
- 构建时 Maven Central 的 TLS 下载失败。已准备临时镜像 init 脚本 `/tmp/vvewell-maven-mirror.gradle`，将 Central 请求改走 Aliyun。该脚本只用于本机这次构建，不在上传源码目录。
- 为缓解空间不足，已将生成的 `alloop-SDK/build` 搬到外置开发盘 `/Volumes/ElementsDev/DeveloperStorage/vvewell-android/github-upload-build`，并在原位置建立指向它的符号链接。这个符号链接指向本机外置盘，**不能上传 GitHub**；构建产物也不是源码。系统盘当时只剩约 1.1 GiB，搬走构建目录后约剩 2.2 GiB，仍接近满盘。
- 已运行 `./gradlew --stop`。检查时没有 Gradle 构建客户端持有锁；先前遗留的 Gradle daemon 已停止/退出。重新构建前仍应确认 `df -h` 有充足空间。
- `alloop-SDK/android/local.properties` 是 Flutter 生成的本机路径配置，`.gitignore` 已忽略；不要提交。不要把本机 `.env` 或任何密钥复制进 App 资源。

## 重要失败记录

1. 初次 Flutter 构建被 Gradle 8.11.1 拦截：当前 Flutter 3.47.3 要求至少 Gradle 8.14.0、AGP 8.11.1、Kotlin 2.2.20。副本构建配置已升级，业务 Dart 代码未因这个问题修改。
2. 随后 `org.ow2.asm:asm-analysis:9.7.1` 从 Maven Central 下载时 TLS 握手失败。单独放入 Gradle 文件缓存并不足以使 Gradle 离线识别该版本；随后用临时 Aliyun init 脚本解决依赖下载。
3. Android 编译继续到原生库合并后因系统盘空间不足而失败。不要再重复全量构建而不先确认系统盘空间；构建缓存和中间文件已在外置盘，APK 尚无可安装版本。

## 再次构建与安装

1. 确认外置盘已挂载、系统盘空间充足、模拟器在线：

   ```sh
   source /Volumes/ElementsDev/DeveloperStorage/vvewell-android/env.sh
   df -h /Users/mac/dev/vvewell-physicalAI/github-upload /Volumes/ElementsDev
   adb devices
   ```

2. 构建 Android arm64 调试包。为避开本机 Maven Central TLS 问题，在 Android 目录运行：

   ```sh
   cd /Users/mac/dev/vvewell-physicalAI/github-upload/alloop-SDK/android
   ./gradlew --stop
   vvewell_dart_defines=$(python3 -c 'import base64; print(base64.b64encode(b"DOCTOR_API_BASE=https://vvewell-web-preview-357361255240.asia-east1.run.app").decode())')
   ./gradlew :app:assembleDebug --console=plain \
     --init-script /tmp/vvewell-maven-mirror.gradle \
     --init-script /tmp/vvewell-canonical-build.gradle \
     -Djava.io.tmpdir=/Volumes/ElementsDev/DeveloperStorage/vvewell-android/tmp \
     -Pdart-defines="$vvewell_dart_defines" \
     -Dorg.gradle.internal.http.connectionTimeout=15000 \
     -Dorg.gradle.internal.http.socketTimeout=30000 \
     -Ptarget-platform=android-arm64 -Ptarget=lib/main.dart
   ```

   只有看到 `BUILD SUCCESSFUL`、APK 文件存在并含 `assets/flutter_assets/kernel_blob.bin`，再实际启动显示页面，才算完成。canonical 临时脚本内容：

   ```groovy
   gradle.projectsLoaded {
       rootProject.afterEvaluate {
           allprojects { project ->
               project.layout.buildDirectory.set(project.layout.buildDirectory.get().asFile.canonicalFile)
           }
       }
   }
   ```

若接手环境没有 `/tmp/vvewell-maven-mirror.gradle`，应先重建等价的临时脚本，或修复其 Gradle 网络代理；不要把有本机绝对路径的镜像脚本写入项目。

3. 找出实际 APK 文件名（App 的 Gradle 脚本自定义了输出名）：

   ```sh
   find /Users/mac/dev/vvewell-physicalAI/github-upload/alloop-SDK/build/app/outputs/apk/debug -name '*.apk' -maxdepth 1 -print
   ```

4. 安装并打开，验证模拟器确实显示 App，而不只是 APK 安装成功：

   ```sh
   adb -s emulator-5554 install -r /实际找到的APK路径
   adb -s emulator-5554 shell am start -W -n com.alloop.blue.test/.MainActivity
   adb -s emulator-5554 shell dumpsys activity activities
   ```

   如安装遇到签名不匹配，先检查模拟器现有包；不要直接卸载，以免清除模拟器内该 App 的数据。必要时截屏检查首页。

## 运行环境与日志

- Flutter 3.47.3 / Dart 3.13.3：`/Volumes/ElementsDev/DeveloperStorage/flutter`
- Android SDK：`/Volumes/ElementsDev/DeveloperStorage/vvewell-android/sdk`
- Java 17；Gradle 用户缓存位于外置盘。
- 上一次有信息的完整 Android 构建日志：`/tmp/vvewell-upload-gradle-mirror.log`（最终因空间不足失败）。
- 当前/最近一次 app-only 任务日志：`/tmp/vvewell-upload-gradle-app.log`；最后一次启动过早遇到旧 Gradle daemon 的 `fileHashes` 锁，之后执行了 `./gradlew --stop`。
- 临时 Central 镜像：`/tmp/vvewell-maven-mirror.gradle`。

## 安全与功能边界

本目录内两份旧演示云账号凭据解密函数已禁用，相关 `.enc` 资产和真实 `.env` 未收录。原生启动流程会捕获云同步初始化错误，界面仍可能启动，但没有配置的云账号不会自动连上 Supabase。模拟器没有真实 BLE 戒指、雷达或热成像设备；只能检查界面启动，不能据此声称硬件采集正常。

Android 模拟器界面及找医生在线追问回复已验证。完整医生推荐卡片、多轮排除逻辑、真实硬件及原生云同步未在本轮验证；未上传 GitHub。
