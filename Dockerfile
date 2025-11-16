FROM node:18-bullseye

# 安装 LibreOffice + Python + 字体
RUN apt-get update && apt-get install -y \
    libreoffice \
    python3 \
    python3-venv \
    python3-pip \
    ffmpeg \
    fonts-noto-cjk \
    fonts-freefont-ttf \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/app

# 安装 Node 依赖（必须包含 devDependencies）
COPY package*.json ./
RUN npm install

# 复制代码
COPY . .

# Python 虚拟环境
RUN python3 -m venv /app/venv && \
    /app/venv/bin/pip install --upgrade pip && \
    /app/venv/bin/pip install -r requirements.txt

# 构建 TS
RUN npm run build

EXPOSE 8080

ENV PYTHON_PATH=/app/venv/bin/python3

CMD ["node", "dist/index.js"]
