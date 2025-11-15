FROM node:18-alpine

# 安装系统依赖（包括编译工具）
RUN apk add --no-cache \
    ffmpeg \
    libreoffice \
    python3 \
    py3-pip \
    # 安装编译工具
    build-base \
    python3-dev \
    # 安装其他必要的库
    musl-dev \
    libffi-dev \
    openssl-dev \
    # 安装中文字体支持
    ttf-freefont \
    font-noto \
    font-noto-cjk \
    # 清理缓存
    && rm -rf /var/cache/apk/* /tmp/*

WORKDIR /app

# 复制 package.json 和安装依赖
COPY package*.json ./
RUN npm install

# 复制源代码
COPY . .

# 创建 Python 虚拟环境并安装依赖（使用预编译的 wheel）
RUN python3 -m venv /app/venv \
    && /app/venv/bin/pip install --upgrade pip \
    && /app/venv/bin/pip install --no-cache-dir \
    pdfplumber \
    python-docx \
    openpyxl \
    pandas \
    python-pptx \
    beautifulsoup4 \
    pdfkit \
    # 单独安装 PyMuPDF（pdf2docx 的依赖）
    && /app/venv/bin/pip install --no-cache-dir PyMuPDF

# 复制 entrypoint 脚本并设置权限
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 创建必要的目录
RUN mkdir -p uploads public src/scripts

# 设置 Python 脚本权限（如果存在）
RUN if [ -d "src/scripts" ]; then chmod +x src/scripts/*.py 2>/dev/null || true; fi

# 暴露端口
EXPOSE 8080

# 使用 entrypoint 脚本
ENTRYPOINT ["/entrypoint.sh"]