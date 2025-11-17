##############################################
# Stage 1: Build Node Application
##############################################
FROM node:18-alpine as node-builder

WORKDIR /app

# 复制 package 文件
COPY package*.json ./
COPY tsconfig.json ./

# 安装所有依赖
RUN npm ci && npm cache clean --force

# 复制源代码 (确保包含所有文件)
COPY src ./src

# 构建 TypeScript 项目
RUN npm run build

# 验证构建结果
RUN ls -la dist/

# 清理 devDependencies
RUN npm prune --production


##############################################
# Stage 2: Build Python Dependencies
##############################################
FROM python:3.11-slim as python-builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc g++ libcairo2-dev libffi-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN python3 -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir -U pip && \
    /opt/venv/bin/pip install --no-cache-dir -r requirements.txt


##############################################
# Stage 3: Runtime
##############################################
FROM node:18-slim

ENV PYTHON_PATH=/opt/venv/bin/python3 \
    NODE_ENV=production

WORKDIR /app

# 只安装运行时依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-venv \
    ca-certificates \
    libcairo2 \
    libffi8 \
    libglib2.0-0 \
    libreoffice-core-nogui \
    libreoffice-writer-nogui \
    libreoffice-calc-nogui \
    libreoffice-impress-nogui \
    fonts-liberation \
    ffmpeg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 复制构建产物
COPY --from=node-builder /app/dist ./dist
COPY --from=node-builder /app/node_modules ./node_modules
COPY --from=node-builder /app/package*.json ./

# 在最终镜像中创建新的 venv，并从构建器中复制已安装的包
RUN python3 -m venv /opt/venv
COPY --from=python-builder /opt/venv/lib/python3.11/site-packages /opt/venv/lib/python3.11/site-packages

# 复制脚本
COPY src/scripts ./src/scripts

# 创建目录
RUN mkdir -p uploads public

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s \
    CMD node -e "require('http').get('http://localhost:8080/health',(r)=>{process.exit(r.statusCode===200?0:1)})"

EXPOSE 8080

CMD ["node", "dist/index.js"]
