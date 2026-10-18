# Vvewell Web 与原生 App 源码

本目录整理自当前线上版本的 `web-preview` 工作区，保留原相对路径，可独立构建。不是重写，也不是仅包含编译后的网页。

- `alloop-SDK/`：小熊猫首页 Flutter App，完整页面、演示数据、Web 适配、Android/iOS 工程及原生硬件代码。
- `web_backend/`：当前 Web 服务、医生推荐 v2、878 医生目录、模型适配及测试。
- `doctor-recommendation/`：旧版推荐逻辑及数据，仍被报告 OCR、健康咨询和兼容接口引用。
- `cloud_db/`：数据库迁移、SQL 测试与工具。0016 迁移尚未应用；历史文档也涉及其他客户端，不代表本 Web 已启用全部功能。
- `web_deploy/`、`Dockerfile`：构建、凭据检查和 Google Cloud Run 部署。

## 本地启动

已验证工具链为 Flutter 3.47.3 / Dart 3.13.3；后端使用 Python 标准库，容器使用 Python 3.12。请自行安装 Flutter、Python，部署另需 Docker/Google Cloud CLI。

```sh
cp .env.example .env
# 在本机 .env 填入真实模型配置；没有模型配置仍可浏览演示界面。
./web_deploy/build.sh
ENV_FILE="$PWD/.env" PORT=4190 python3 web_backend/server.py
```

打开 http://127.0.0.1:4190 。构建会生成 `.web-dist/`；该产物不需要提交 GitHub。

## 验证与部署

```sh
python3 -m unittest discover -s web_backend/tests
cd alloop-SDK
flutter test test/web_preview_test.dart test/medical_ocr_service_test.dart
```

现有部署：项目 `claw-wendy`，Cloud Run 服务 `vvewell-web-preview`，区域 `asia-east1`。整理操作没有修改线上部署。

线上地址：https://vvewell-web-preview-357361255240.asia-east1.run.app/

部署方法及功能边界见 [WEB_PREVIEW.md](WEB_PREVIEW.md)。`web_deploy/deploy.py` 会写入 Secret Manager、部署并切换正式流量，只有决定发布时才运行。

## 原生硬件与凭据

保留蓝牙、戒指、雷达、热成像、机器人、rPPG 等源码，以及项目必需的 AAR/JAR/SO/ONNX 文件。Web 浏览器中的硬件入口使用报告/记录适配，真实采集仍需手机及设备。

没有携带 `.env`、旧演示账户加密包或其解密密钥、签名文件、个人 SDK 路径。原演示健康数据与 UI 仍保留。原生端若依赖旧嵌入账户自动登录，需要另外配置本人账户；重新签名需使用自己的签名配置。两份解密函数仅在此副本禁用，原工作区未修改。

厂商二进制 SDK 的公开再分发许可尚未核验；公开 GitHub 仓库前应确认授权。详见 [UPLOAD_MANIFEST.md](UPLOAD_MANIFEST.md)。
