FROM mcr.microsoft.com/dotnet/aspnet:10.0

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

# 复制编译产物
WORKDIR /app
COPY api/app/ /app/api/
COPY admin-ui/html/ /app/admin-ui/
COPY user-ui/html/ /app/user-ui/

# 复制配置
COPY nginx/default.conf /etc/nginx/sites-available/default
COPY redis/redis.conf /etc/redis/redis.conf
COPY supervisor/supervisord.conf /etc/supervisor/supervisord.conf
COPY supervisor/app.conf /etc/supervisor/conf.d/app.conf
COPY scripts/start-api.sh /app/start-api.sh
COPY entrypoint.sh /entrypoint.sh

# 权限 + 修复 Windows 行尾
RUN sed -i 's/\r$//' /entrypoint.sh /app/start-api.sh && \
    chmod +x /app/start-api.sh /entrypoint.sh && \
    chown -R www-data:www-data /app/admin-ui /app/user-ui && \
    mkdir -p /var/lib/postgresql/data /var/lib/redis /var/log/supervisor && \
    chown -R postgres:postgres /var/lib/postgresql && \
    chown -R redis:redis /var/lib/redis

EXPOSE 8080 8081 8082

ENTRYPOINT ["/entrypoint.sh"]
