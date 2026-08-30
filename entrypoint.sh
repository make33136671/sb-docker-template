#!/bin/bash
set -e

PG_BIN="/usr/lib/postgresql/bin"
PG_DATA="/var/lib/postgresql/data"

# 修复挂载卷的权限
chown -R postgres:postgres /var/lib/postgresql 2>/dev/null || true
chown -R redis:redis /var/lib/redis 2>/dev/null || true
mkdir -p /root/.aspnet/DataProtection-Keys

# 首次运行：初始化 PostgreSQL
if [ ! -f "$PG_DATA/PG_VERSION" ]; then
    echo "→ Initializing PostgreSQL..."
    mkdir -p "$PG_DATA"
    chown -R postgres:postgres /var/lib/postgresql
    su postgres -c "$PG_BIN/initdb -D $PG_DATA --auth=trust --encoding=UTF8"

    # 临时启动 PostgreSQL 来设置密码和建库
    su postgres -c "$PG_BIN/pg_ctl -D $PG_DATA -w -o '-c listen_addresses=localhost' start"
    su postgres -c "psql -c \"ALTER USER postgres PASSWORD '${POSTGRES_PASSWORD}';\""
    su postgres -c "createdb ${POSTGRES_DB:-sb_myapp}" 2>/dev/null || true
    su postgres -c "$PG_BIN/pg_ctl -D $PG_DATA -w stop"

    # 配置 pg_hba.conf：本地 trust，远程 md5
    cat > "$PG_DATA/pg_hba.conf" << 'EOF'
local   all             all                                     trust
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5
EOF
    chown postgres:postgres "$PG_DATA/pg_hba.conf"

    echo "✓ PostgreSQL initialized (database: ${POSTGRES_DB:-sb_myapp})"
else
    # 非首次运行：同步密码（防止 .env 密码变更后无法连接）
    echo "→ Syncing PostgreSQL password..."
    su postgres -c "$PG_BIN/pg_ctl -D $PG_DATA -w -o '-c listen_addresses=localhost' start" 2>/dev/null || true
    su postgres -c "psql -c \"ALTER USER postgres PASSWORD '${POSTGRES_PASSWORD}';\"" 2>/dev/null || true
    su postgres -c "$PG_BIN/pg_ctl -D $PG_DATA -w stop" 2>/dev/null || true
    echo "✓ PostgreSQL password synced"
fi

echo "→ Starting all services (nginx + postgres + redis + api)..."
exec supervisord -n -c /etc/supervisor/supervisord.conf
