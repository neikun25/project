##############################################
# Stage 1: Build Node (install TS)
##############################################
FROM node:18 as builder

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build



##############################################
# Stage 2: Runtime Environment (Debian slim)
##############################################
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# 安装 LibreOffice（headless 版本，无 GUI）
RUN apt-get update && apt-get install -y \
    libreoffice-core \
    libreoffice-writer \
    libreoffice-calc \
    libreoffice-impress \
    libreoffice-common \
    libreoffice-java-common \
    python3 \
    python3-venv \
    python3-pip \
    fonts-noto-cjk \
    ffmpeg \
    && apt-get clean && rm -rf /var/lib/apt/lists/*


WORKDIR /app

################ Install Python ################
COPY requirements.txt .
RUN python3 -m venv /app/venv && \
    /app/venv/bin/pip install --upgrade pip && \
    /app/venv/bin/pip install -r requirements.txt


################ Copy Node Build Output ################
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package*.json ./
RUN npm install --omit=dev


################ Copy Scripts ################
COPY src/scripts ./src/scripts
COPY uploads ./uploads

ENV PYTHON_PATH=/app/venv/bin/python3

EXPOSE 8080

CMD ["node", "dist/index.js"]
