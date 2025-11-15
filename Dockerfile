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

# 安装 Python 依赖
RUN pip3 install -r requirements.txt

# 构建 TypeScript
RUN npm run build

# 创建必要的目录
RUN mkdir -p uploads public src/scripts

# 复制 Python 脚本到正确位置
COPY *.py ./src/scripts/

# 设置 Python 脚本权限
RUN chmod +x ./src/scripts/*.py

EXPOSE 8080

CMD ["node", "dist/index.js"]