# 使用 Python 3.12 作为基础镜像
FROM python:3.11-bullseye

USER root
RUN sed -i 's|http://.*.ubuntu.com|http://mirrors.aliyun.com|g' /etc/apt/sources.list

# 设置工作目录
WORKDIR /app

# 设置环境变量
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    CONFIG_PATH=/app/config.ini

# 安装系统依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# 复制依赖文件
COPY requirements.txt .

# 安装 Python 依赖
RUN pip install --upgrade pip && \
    pip install -r requirements.txt

# 复制项目文件
COPY . .

# 创建非 root 用户（可选，提高安全性）
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app
USER appuser

# 暴露 HTTP 服务端口（默认 9000，可通过环境变量 API_PORT 修改）
EXPOSE 9000

# 设置默认命令：运行 HTTP API 服务
# 使用环境变量 API_HOST 和 API_PORT 来配置监听地址和端口
CMD ["sh", "-c", "uvicorn api.api_server:app --host ${API_HOST:-0.0.0.0} --port ${API_PORT:-9000}"]

