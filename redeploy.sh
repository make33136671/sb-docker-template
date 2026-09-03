#!/bin/bash
set -e

echo "══════════════════════════════════════════════"
echo "  SB Framework Docker 重新部署"
echo "══════════════════════════════════════════════"

# 检查 .env 是否存在
if [ ! -f .env ]; then
    echo "✗ 未找到 .env 配置文件！"
    echo ""
    echo "  首次部署请运行: bash deploy.sh"
    echo "  它会自动生成 .env（含数据库密码和端口配置）"
    exit 1
fi

# 加载环境变量
set -a
source .env
set +a

echo "→ 停止旧容器..."
docker compose down

echo ""
echo "→ 重新构建镜像..."
# 不用 --no-cache: 基座层(apt)三层共享缓存, --no-cache 会连系统组件一起重建(数分钟);
# 产物变化时 COPY 层缓存自然失效, 只有确需重装系统组件时才手动加 --no-cache
docker compose build

echo ""
echo "→ 启动容器..."
docker compose up -d

echo ""
echo "→ 等待服务就绪..."
sleep 15

echo ""
echo "══════════════════════════════════════════════"
echo "  ✓ 重新部署完成！"
echo ""
echo "  用户端:  http://<你的域名>           → 端口 ${USER_PORT:-8080}"
echo "  管理端:  http://admin.<你的域名>     → 端口 ${ADMIN_PORT:-8081}"
echo "  API:     http://<你的域名>/api/      → 端口 ${API_PORT:-8082}"
echo ""
echo "  PostgreSQL 密码: ${POSTGRES_PASSWORD}"
echo ""
echo "══════════════════════════════════════════════"
echo ""
docker compose ps
echo ""
echo "══════════════════════════════════════════════"
