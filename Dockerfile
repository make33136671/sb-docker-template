# ═══════════════════════════════════════════════════════════════
#  SB Framework 三层镜像：基座(base) → 生产(prod) → 维护(maint)
#  构建: docker build --target prod -t myapp .        （生产默认）
#        docker build --target maint -t myapp-maint . （排障维护）
#  基座层改动会随构建链自动进入生产/维护层，无需同步操作
# ═══════════════════════════════════════════════════════════════

# ── ① 基座：系统组件 + 服务配置 + 入口（变化频率最低，放最前保证三层共享缓存）──
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS base

# 安装所有服务（使用基础镜像默认 Debian 源，GPG 密钥已正确配置）
RUN apt-get update -o Acquire::Retries=5 && \
    apt-get install -y --no-install-recommends \
        nginx \
        supervisor \
        postgresql \
        redis-server \
        curl \
    && rm -rf /var/lib/apt/lists/*

# 创建 PostgreSQL 版本无关的 bin 路径
RUN PG_VER=$(ls /usr/lib/postgresql/ | sort -V | tail -1) && \
    ln -s /usr/lib/postgresql/${PG_VER}/bin /usr/lib/postgresql/bin

# 复制配置（"服务怎么跑"的定义全在基座层；生产/维护层绝不 COPY 配置）
WORKDIR /app
COPY nginx/default.conf /etc/nginx/sites-available/default
COPY redis/redis.conf /etc/redis/redis.conf
COPY supervisor/supervisord.conf /etc/supervisor/supervisord.conf
COPY supervisor/app.conf /etc/supervisor/conf.d/app.conf
COPY scripts/start-api.sh /app/start-api.sh
COPY scripts/bootstrap-app.sh /usr/local/bin/bootstrap-app.sh
COPY entrypoint.sh /entrypoint.sh

# 权限 + 修复 Windows 行尾
RUN sed -i 's/\r$//' /entrypoint.sh /app/start-api.sh /usr/local/bin/bootstrap-app.sh && \
    chmod +x /app/start-api.sh /entrypoint.sh /usr/local/bin/bootstrap-app.sh && \
    mkdir -p /var/lib/postgresql/data /var/lib/redis /var/log/supervisor && \
    chown -R postgres:postgres /var/lib/postgresql && \
    chown -R redis:redis /var/lib/redis

EXPOSE 8080 8081 8082

ENTRYPOINT ["/entrypoint.sh"]

# ── ② 生产：基座 + 编译产物（线上默认镜像；latest 只指向它）──
FROM base AS prod
COPY api/app/ /app/api/
COPY admin-ui/html/ /app/admin-ui/
COPY user-ui/html/ /app/user-ui/
RUN chown -R www-data:www-data /app/admin-ui /app/user-ui

# ── ③ 维护：生产 + 维护工具 + /app 种子（排障用，不常驻生产）──
FROM prod AS maint
RUN apt-get update -o Acquire::Retries=5 && \
    apt-get install -y --no-install-recommends \
        unzip \
        wget \
        vim \
        less \
        procps \
    && rm -rf /var/lib/apt/lists/*
# /app 完整种子（含 start-api.sh）：维护态把宿主机目录 bind-mount 到 /app 时，
# 首次启动由 bootstrap-app.sh 从这里播种；生产镜像无 /opt/app-seed，bootstrap 空转
RUN cp -a /app/. /opt/app-seed/
