##############################################
# Stage 1: Build Node
##############################################
FROM node:18-alpine as node-builder

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force
COPY . .
RUN npm run build


##############################################
# Stage 2: Build Python Dependencies
##############################################
FROM python:3.11-slim as python-builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    libcairo2-dev \
    libffi-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN python3 -m venv /opt/venv && \
    . /opt/venv/bin/activate && \
    pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt


##############################################
# Stage 3: Runtime (最小化)
##############################################
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHON_PATH=/opt/venv/bin/python3 \
    NODE_VERSION=18

WORKDIR /app

# 安装 Node.js 和运行时依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    && curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y --no-install-recommends \
    nodejs \
    python3 \
    libcairo2 \
    libffi8 \
    libglib2.0-0 \
    # LibreOffice 核心(无 GUI)
    libreoffice-core-nogui \
    libreoffice-writer-nogui \
    libreoffice-calc-nogui \
    libreoffice-impress-nogui \
    # 最小字体集
    fonts-liberation \
    # 如需中文支持,取消下行注释
    # fonts-wqy-microhei \
    # FFmpeg (如不需要视频处理,可删除此行)
    ffmpeg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/* \
    && rm -rf /var/cache/* \
    && rm -rf /usr/share/doc/* \
    && rm -rf /usr/share/man/* \
    && rm -rf /usr/share/locale/* \
    && apt-get purge -y --auto-remove curl

# 复制 Node 应用
COPY --from=node-builder /app/dist ./dist
COPY --from=node-builder /app/node_modules ./node_modules
COPY --from=node-builder /app/package.json ./

# 复制 Python 虚拟环境
COPY --from=python-builder /opt/venv /opt/venv

# 复制脚本
COPY src/scripts ./src/scripts

# 创建目录
RUN mkdir -p uploads public && \
    chmod 755 uploads public

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD node -e "require('http').get('http://localhost:8080/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

EXPOSE 8080

CMD ["node", "dist/index.js"]