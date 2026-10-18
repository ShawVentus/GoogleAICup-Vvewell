# Vvewell

Source code for Vvewell, an AI-powered health companion for Web, iOS, and Android, built with Flutter and a Python backend.

## Features

- Conversational doctor recommendations powered by Google Gemini.
- Medical report upload, OCR, and health consultations.
- Nutrition, medication, sleep, and family health tracking, with demo workflows.
- Native integrations for smart rings, radar, thermal imaging, and camera-based heart rate measurement. Hardware measurements require a supported mobile device and connected equipment.

[Live demo](https://vvewell-web-preview-357361255240.asia-east1.run.app/)

## Run locally

Requires Flutter and Python 3.12.

```sh
cp .env.example .env
# Add your model API credentials to .env to enable AI features.
./web_deploy/build.sh
ENV_FILE="$PWD/.env" PORT=4190 python3 web_backend/server.py
```

Open http://127.0.0.1:4190. The demo interface can be browsed without model credentials.

See [WEB_PREVIEW.md](WEB_PREVIEW.md) for build, testing, and deployment details.
