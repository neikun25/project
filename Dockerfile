FROM node:lts-alpine

# 安装系统依赖
RUN apk add --no-cache \
    ffmpeg \
    libreoffice \
    python3 \
    py3-pip \
    ttf-freefont \
    font-noto \
    font-noto-cjk

WORKDIR /usr/src/app

# 复制 package.json 并安装依赖
COPY package*.json ./
RUN npm install

# 复制源代码
COPY . .

# 创建 Python 虚拟环境并安装依赖
RUN python3 -m venv /app/venv && \
    /app/venv/bin/pip install --upgrade pip && \
    /app/venv/bin/pip install -r requirements.txt

# 构建 TypeScript
RUN npm run build

# 创建必要的目录
RUN mkdir -p uploads public src/scripts

# 复制 Python 脚本到正确位置
COPY *.py ./src/scripts/

# 设置 Python 脚本权限
RUN chmod +x ./src/scripts/*.py

EXPOSE 8080

# 设置 Python 路径环境变量
ENV PYTHON_PATH=/app/venv/bin/python3

CMD ["node", "dist/index.js"]