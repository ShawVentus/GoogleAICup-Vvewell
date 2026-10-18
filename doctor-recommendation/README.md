# 医生推荐：实时后端接入版

Flutter 对话页通过 `/api/recommend` 请求 Python 服务。Python 使用模型解析病情，并从 `3-数据` 的医生、医院 CSV 中检索和排序；前端不再加载 `assets/demo.json`。尚未接入 Supabase。

## 启动

先编译前端：

```sh
source /Volumes/ElementsDev/DeveloperStorage/vvewell-android/env.sh
cd /Users/mac/dev/vvewell-physicalAI/doctor-recommendation-preview/1-前端代码
flutter pub get
flutter build web --release --no-wasm-dry-run
```

启动同源网页和 API（仅监听本机）：

```sh
cd /Users/mac/dev/vvewell-physicalAI/doctor-recommendation-preview/2-推荐逻辑
ENV_FILE=/Users/mac/dev/vvewell-physicalAI/.env GEMINI_MODEL=gemini-3.8-flash python3 server.py 4186
```

打开 http://127.0.0.1:4186 。填写就诊人年龄、出生性别和当前所在地，再选择示例或输入病情发送。模型追问时，下次发送会附带原问题和回答；可点击“结束追问，咨询新问题”重置。

后端从 `ENV_FILE` 读取 `GEMINI_URL` 和 `GEMINI_API`。密钥不会传给 Flutter 或浏览器。支持通过 `GEMINI_MODEL` 指定模型；第二次紧急程度判断默认使用同模型、独立提示词，可用 `DANGER_MODEL_2` 覆盖。

若使用其他 OpenAI 兼容服务，设置完整的 `LLM_URL`（含 `/chat/completions`）、`LLM_API_KEY`、`LLM_MODEL`。健康检查：`GET /api/health`。

Android 构建时需通过 `--dart-define=API_BASE_URL=https://你的后端域名` 指定实际后端；当前只提供本机网页预览，未部署公网服务。

## 验证

```sh
cd 1-前端代码
flutter test --dart-define=API_BASE_URL=http://127.0.0.1:4186
dart analyze lib
cd ../2-推荐逻辑
python3 tests/test_doctor.py
python3 -m unittest discover -s tests -p test_api.py
```

模型故障时 API 返回失败，不把离线关键词推荐当成真实结果。年龄等档案缺失时普通请求返回 400；明确急症规则不等待年龄补全或模型队列。

当前沿用原后端的本地请求日志（`2-推荐逻辑/logs/`），包含病情文本。其余四个底部页面仍是占位页。

2026-10-18 超时修复：兼容模型将说明文字、Markdown 代码框与最终 JSON 混合返回的情况；只读取完整的尾部 JSON 对象。每次模型请求的 socket 等待上限改为 30 秒，解析与独立紧急判断各最多尝试两次，退避最多 5 秒。移除了用于润色开场白的第三次模型请求，网页复用已有模板说明与医生卡片。

连续对话：前端携带最近对话（最多 8 条，并保留本次咨询的最初描述）与已展示医生编号。模型识别医院偏好、“更多医生”意图；指定医院时不以其他医院补足，更多推荐每次最多 6 位且排除已展示医生。找不到更多时明确提示。点击“开始新咨询”或修改就诊人资料会清空上下文。

英文版：界面、表单、示例、错误提示和推荐输出默认英文。医院名称优先使用 hospital.csv 中的 name_en，缺失项使用 server.py 中的英文译名；区域使用英文。医生姓名使用 ICU Han-Latin 转写后保存到 doctor_names_en.json，属于拼音展示，并非经核验的官方英文姓名；更新 doctor.csv 时需同步更新该映射。职称使用标准英文简写，科室使用标准科室英文名。医生卡片不再展示官网擅长原文、展开按钮及匹配关键词，底层数据仍用于检索。
