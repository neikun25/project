FROM node:lts-alpine

# 安装系统依赖
RUN apk add --no-cache \
    ffmpeg \
    libreoffice \
    python3 \
    ttf-freefont \
    font-noto \
    font-noto-cjk

WORKDIR /usr/src/app

# 复制 package.json 并安装所有依赖
COPY package*.json ./
RUN npm install

# 复制源代码
COPY . .

# 构建 TypeScript
RUN npm run build

# 创建必要的目录
RUN mkdir -p uploads public

EXPOSE 8080

CMD ["node", "dist/index.js"]