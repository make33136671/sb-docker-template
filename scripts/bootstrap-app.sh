#!/bin/bash
# bootstrap-app.sh —— 仅维护镜像(maint target)携带
# 用途: 宿主机目录 bind-mount 到 /app 会遮蔽镜像内容; 首次启动从镜像内种子播种,
#       只初始化、绝不覆盖宿主机已有文件（以 start-api.sh 存在为标志）
set -e

SEED=/opt/app-seed
APP=/app

if [ ! -d "$SEED" ]; then
    echo "→ no app seed in image, skip bootstrap"
    exit 0
fi

if [ -e "$APP/start-api.sh" ]; then
    echo "→ /app already initialized, skip bootstrap"
    exit 0
fi

echo "→ /app is empty (bind-mounted), seeding from image..."
mkdir -p "$APP"
cp -a "$SEED"/. "$APP"/

# 重放镜像构建时做过的权限处理
sed -i 's/\r$//' "$APP/start-api.sh" 2>/dev/null || true   # 防 Windows 编辑回写 CRLF
chmod +x "$APP/start-api.sh"
chown -R www-data:www-data "$APP/admin-ui" "$APP/user-ui" 2>/dev/null || true

echo "✓ /app seeded (重新播种/版本升级: down → 清空宿主机 app/ 目录 → up)"
