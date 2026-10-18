FROM python:3.12-slim
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 HOST=0.0.0.0 PORT=8080
COPY .web-dist/ .web-dist/
COPY web_backend/ web_backend/
COPY doctor-recommendation/2-推荐逻辑/ doctor-recommendation/2-推荐逻辑/
COPY doctor-recommendation/3-数据/ doctor-recommendation/3-数据/
RUN useradd --create-home app && mkdir -p /app/doctor-recommendation/2-推荐逻辑/logs && chown -R app:app /app/doctor-recommendation/2-推荐逻辑/logs
USER app
CMD ["python", "web_backend/server.py"]
