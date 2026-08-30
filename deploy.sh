#!/bin/bash
set -e

echo "══════════════════════════════════════════════"
echo "  SB Framework Docker 一键部署（单容器）"
echo "══════════════════════════════════════════════"

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo "✗ 未检测到 Docker，请先安装 Docker 和 Docker Compose"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo "✗ 未检测到 Docker Compose，请先安装"
    exit 1
fi

# 首次运行：生成 .env
if [ ! -f .env ]; then
    echo "→ 首次部署，正在生成配置..."

    POSTGRES_PASSWORD=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 24)

    cat > .env << EOF
# ═════════════════════════════════════════════════════════
#  SB Framework 单容器部署配置（自动生成）
# ═════════════════════════════════════════════════════════

# 项目名（影响容器名、数据库名、Redis前缀）
PROJECT_NAME=myapp

# API DLL 文件名（改为你的项目实际 DLL 名）
APP_DLL_NAME=MyApp.WebApi.dll

# 对外端口（三端口分离）
USER_PORT=8080
ADMIN_PORT=8081
API_PORT=8082

# PostgreSQL（密码已自动生成）
POSTGRES_DB=sb_myapp
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

# 数据持久化
# 留空 = Docker 命名卷（内置）
# 填路径 = 绑定挂载到宿主目录（外置）
#   POSTGRES_DATA_PATH=./data/postgres
#   REDIS_DATA_PATH=./data/redis
POSTGRES_DATA_PATH=
REDIS_DATA_PATH=
EOF

    echo "✓ 已生成 .env 配置文件"
    echo ""
    echo "  ⚠ 请修改 .env 中的 PROJECT_NAME 和 APP_DLL_NAME 为你的项目实际值"
    echo ""
    echo "  然后重新运行: bash deploy.sh"
    echo ""
    exit 0
fi

# 加载环境变量
set -a
source .env
set +a

echo "→ 构建镜像（首次约 3~5 分钟）..."
docker compose build

echo ""
echo "→ 启动容器..."
docker compose up -d

echo ""
echo "→ 等待服务就绪..."
sleep 15

echo ""
echo "══════════════════════════════════════════════"
echo "  ✓ 部署完成！单容器运行全部服务"
echo ""
echo "  用户端:  http://<你的域名>           → 端口 ${USER_PORT:-8080}"
echo "  管理端:  http://admin.<你的域名>     → 端口 ${ADMIN_PORT:-8081}"
echo "  API:     http://<你的域名>/api/      → 端口 ${API_PORT:-8082}"
echo ""
echo "  PostgreSQL 密码: ${POSTGRES_PASSWORD}"
echo ""
echo "  ⚠ 请记录以上密码！也可在 .env 文件中查看"
echo ""
echo "  域名和 SSL 在宿主机/CDN 层配置"
echo "══════════════════════════════════════════════"
echo ""
docker compose ps
echo ""
echo "══════════════════════════════════════════════"
