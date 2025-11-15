FROM node:lts-alpine

# 安装系统依赖
RUN apk add --no-cache \
    ffmpeg \
    libreoffice \
    python3 \
    ttf-freefont \
    font-noto \
    font-noto-cjk \
    && rm -rf /var/cache/apk/*

ENV NODE_ENV=production
WORKDIR /usr/src/app

# 复制 package.json 文件
COPY package*.json ./

# 安装依赖
RUN npm ci --only=production --silent

# 复制源代码
COPY . .

# 构建 TypeScript
RUN npm run build

# 创建必要的目录
RUN mkdir -p uploads public src/scripts

EXPOSE 8080

# 设置权限和用户
RUN chown -R node /usr/src/app
USER node

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:8080/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })"

CMD ["node", "dist/index.js"]