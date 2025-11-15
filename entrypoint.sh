#!/bin/bash
# wx-convert-backend entrypoint script for Sealos

set -e

echo "=== 文件转换服务启动脚本 ==="
echo "当前时间: $(date)"
echo "工作目录: $(pwd)"

# 激活 Python 虚拟环境
if [ -f "/app/venv/bin/activate" ]; then
    source /app/venv/bin/activate
    echo "✓ Python 虚拟环境已激活"
else
    echo "⚠ Python 虚拟环境未找到"
fi

# 设置默认环境变量
export PORT=${PORT:-8080}
export HOST=${HOST:-"0.0.0.0"}
export PUBLIC_DIR=${PUBLIC_DIR:-"public"}
export UPLOAD_DIR=${UPLOAD_DIR:-"uploads"}
export MAX_FILE_SIZE_BYTES=${MAX_FILE_SIZE_BYTES:-104857600}  # 100MB
export PUBLIC_BASE_URL=${PUBLIC_BASE_URL:-"http://localhost:8080"}

# 转换工具路径设置
export FFMPEG_PATH=${FFMPEG_PATH:-"ffmpeg"}
export SOFFICE_PATH=${SOFFICE_PATH:-"soffice"}
export PYTHON_PATH=${PYTHON_PATH:-"/app/venv/bin/python3"}  # 使用虚拟环境中的 Python

# ... 其余部分保持不变 ...

# 创建必要的目录
echo "创建必要的目录..."
mkdir -p ${UPLOAD_DIR} ${PUBLIC_DIR} src/scripts

# 检查必要的系统依赖
echo "=== 检查系统依赖 ==="
check_dependency() {
    if command -v $1 &> /dev/null; then
        echo "✓ $1 已安装: $(command -v $1)"
        $1 --version 2>/dev/null | head -n1 || echo "  - 版本信息不可用"
        return 0
    else
        echo "⚠ $1 未安装"
        return 1
    fi
}

# 检查基础依赖
check_dependency node
check_dependency npm

# 检查转换工具
echo "=== 检查转换工具 ==="
check_dependency ffmpeg || echo "警告: FFmpeg 未安装，音频转换功能将不可用"
check_dependency soffice || echo "警告: LibreOffice 未安装，文档转换功能将受限"
check_dependency python3 || echo "警告: Python3 未安装，高级转换功能将不可用"

# 检查 Python 包
if command -v python3 &> /dev/null; then
    echo "=== 检查 Python 依赖 ==="
    python3 -c "
import importlib.util
import sys

required_packages = [
    ('pdf2docx', 'pdf2docx'),
    ('pdfplumber', 'pdfplumber'), 
    ('docx', 'python-docx'),
    ('openpyxl', 'openpyxl'),
    ('pandas', 'pandas'),
    ('pptx', 'python-pptx'),
    ('bs4', 'beautifulsoup4'),
    ('pdfkit', 'pdfkit')
]

print('Python 环境检查:')
print(f'Python 版本: {sys.version}')

for pkg_import, pkg_name in required_packages:
    try:
        spec = importlib.util.find_spec(pkg_import)
        if spec is not None:
            print(f'✓ {pkg_name} 可用')
        else:
            print(f'⚠ {pkg_name} 未安装')
    except Exception as e:
        print(f'⚠ {pkg_name} 检查失败: {e}')
"
else
    echo "Python3 不可用，跳过 Python 依赖检查"
fi

# 安装 Node.js 依赖
echo "=== 安装 Node.js 依赖 ==="
if [ -f "package.json" ]; then
    echo "安装依赖包..."
    npm install --production=false
else
    echo "错误: package.json 不存在"
    exit 1
fi

# TypeScript 编译
echo "=== 编译 TypeScript 代码 ==="
if [ -f "tsconfig.json" ]; then
    echo "执行 TypeScript 编译..."
    npm run build
    
    if [ $? -eq 0 ]; then
        echo "✓ TypeScript 编译成功"
        
        # 检查编译输出
        if [ -f "dist/index.js" ]; then
            echo "✓ 找到编译文件: dist/index.js"
        else
            echo "⚠ 编译完成但未找到 dist/index.js"
        fi
    else
        echo "✗ TypeScript 编译失败"
        exit 1
    fi
else
    echo "⚠ 未找到 tsconfig.json，跳过编译"
fi

# 检查 Python 脚本
echo "=== 检查 Python 脚本 ==="
if [ -d "src/scripts" ]; then
    echo "Python 脚本目录内容:"
    ls -la src/scripts/ 2>/dev/null || echo "src/scripts 目录为空或不存在"
    
    # 设置 Python 脚本权限
    if [ -n "$(ls -A src/scripts/*.py 2>/dev/null)" ]; then
        echo "设置 Python 脚本执行权限..."
        chmod +x src/scripts/*.py
    fi
else
    echo "⚠ 未找到 src/scripts 目录"
fi

# 设置文件权限
echo "设置文件权限..."
chmod -R 755 uploads public

# 健康检查函数
health_check() {
    echo "执行健康检查..."
    for i in {1..30}; do
        if curl -f http://localhost:${PORT}/health >/dev/null 2>&1; then
            echo "✓ 服务健康检查通过"
            return 0
        fi
        echo "等待服务启动... ($i/30)"
        sleep 2
    done
    echo "✗ 服务健康检查失败"
    return 1
}

# 清理函数
cleanup() {
    echo "收到停止信号，正在清理..."
    if [ ! -z "$APP_PID" ]; then
        kill $APP_PID 2>/dev/null || true
        wait $APP_PID 2>/dev/null || true
    fi
    echo "服务已停止"
    exit 0
}

# 设置信号处理
trap cleanup SIGTERM SIGINT

# 启动应用程序
echo "=== 启动文件转换服务 ==="
echo "端口: $PORT"
echo "主机: $HOST"
echo "上传目录: $UPLOAD_DIR"
echo "公共目录: $PUBLIC_DIR"
echo "最大文件大小: $MAX_FILE_SIZE_BYTES 字节"
echo "公共访问地址: $PUBLIC_BASE_URL"

# 根据编译结果选择启动方式
if [ -f "dist/index.js" ]; then
    echo "使用编译后的 JavaScript 启动..."
    node dist/index.js &
else
    echo "使用 tsx 启动开发模式..."
    npx tsx index.ts &
fi

APP_PID=$!

# 等待并检查服务状态
if health_check; then
    echo "=== 文件转换服务启动成功 ==="
    echo "服务地址: http://${HOST}:${PORT}"
    echo "健康检查: http://${HOST}:${PORT}/health"
    echo "状态检查: http://${HOST}:${PORT}/server-status"
    echo "支持格式: http://${HOST}:${PORT}/supported-formats"
    echo "================================"
    
    # 等待应用程序进程
    wait $APP_PID
else
    echo "=== 文件转换服务启动失败 ==="
    kill $APP_PID 2>/dev/null || true
    exit 1
fi