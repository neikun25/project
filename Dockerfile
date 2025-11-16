##############################################
# Stage 1: Build Node Application
##############################################
FROM node:18-alpine as node-builder

WORKDIR /app

# 复制 package 文件
COPY package*.json ./

# 安装所有依赖(包括 devDependencies,用于构建)
RUN npm ci && npm cache clean --force

# 复制源代码
COPY . .

# 构建 TypeScript 项目
RUN npm run build

# 删除 devDependencies,只保留生产依赖
RUN npm prune --production


##############################################
# Stage 2: Build Python Dependencies
##############################################
FROM python:3.11-slim as python-builder

WORKDIR /app

# 安装编译工具
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    libcairo2-dev \
    libffi-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# 安装 Python 依赖
COPY requirements.txt .
RUN python3 -m venv /opt/venv && \
    . /opt/venv/bin/activate && \
    pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt


##############################################
# Stage 3: Runtime Image (最小化)
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
    # FFmpeg (如不需要可删除)
    ffmpeg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/* \
    && rm -rf /var/cache/* \
    && rm -rf /usr/share/doc/* \
    && rm -rf /usr/share/man/* \
    && rm -rf /usr/share/locale/* \
    && apt-get purge -y --auto-remove curl

# 从 node-builder 复制构建产物和生产依赖
COPY --from=node-builder /app/dist ./dist
COPY --from=node-builder /app/node_modules ./node_modules
COPY --from=node-builder /app/package*.json ./

# 从 python-builder 复制 Python 虚拟环境
COPY --from=python-builder /opt/venv /opt/venv

# 复制脚本
COPY src/scripts ./src/scripts

# 创建必要目录
RUN mkdir -p uploads public && \
    chmod 755 uploads public

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD node -e "require('http').get('http://localhost:8080/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

EXPOSE 8080

CMD ["node", "dist/index.js"]