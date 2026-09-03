# SB Framework Docker 单容器部署模板

适用于所有 sb-framework 派生项目。单容器运行全部服务（Nginx + PostgreSQL + Redis + .NET API）。

## 使用方法

### 1. 复制模板到项目

```bash
cp -r sb/sb-docker-template apps/myapp/myapp-docker
cd apps/myapp/myapp-docker
```

### 2. 放入编译产物

| 目录 | 内容 | 构建命令示例 |
|------|------|-------------|
| `admin-ui/html/` | Admin 前端构建产物 | `cd admin && pnpm build` → 复制 `dist/` 内容 |
| `user-ui/html/` | 用户端前端构建产物 | `cd user && pnpm build` → 复制 `dist/` 内容 |
| `api/app/` | .NET API 发布产物 | `dotnet publish -c Release -o api/app` |

### 3. 修改项目配置

编辑 `.env`（由 deploy.sh 自动生成，或手动修改 `.env.example`）：

```bash
PROJECT_NAME=myapp          # 项目名（影响容器名、数据库名、Redis前缀）
APP_DLL_NAME=MyApp.WebApi.dll  # API DLL 文件名
```

### 4. 一键部署

```bash
bash deploy.sh
```

## 目录结构

```
myapp-docker/
├── Dockerfile              # 单容器构建文件
├── docker-compose.yml      # 编排配置
├── deploy.sh               # 首次部署脚本（生成 .env + 构建启动）
├── redeploy.sh             # 重新部署脚本（更新代码后使用）
├── entrypoint.sh           # 容器入口（PostgreSQL 初始化 + 密码同步）
├── .env.example            # 配置参考（实际 .env 由 deploy.sh 生成）
├── .dockerignore
├── nginx/
│   └── default.conf        # 三端口分离路由
├── supervisor/
│   ├── supervisord.conf    # Supervisor 主配置
│   └── app.conf            # 各服务进程配置
├── redis/
│   └── redis.conf          # Redis 配置
├── scripts/
│   └── start-api.sh       # API 启动脚本（等 PG/Redis 就绪后启动）
├── admin-ui/html/          # ← 放入 Admin 前端构建产物
├── user-ui/html/           # ← 放入用户端前端构建产物
└── api/app/                # ← 放入 .NET API 发布产物
```

## 端口说明

| 端口 | 服务 | 用途 |
|------|------|------|
| 8080 | user-ui + API | 用户端 |
| 8081 | admin-ui + API | 管理端 |
| 8082 | API 直通 | API 直连 |

## 域名配置

在宿主机 Nginx 配置子域名转发到 Docker 容器：

```nginx
# admin.example.com → 管理端
server {
    listen 80;
    server_name admin.example.com;
    location / { proxy_pass http://127.0.0.1:8081; }
}

# example.com / www.example.com → 用户端
server {
    listen 80;
    server_name example.com www.example.com;
    location / { proxy_pass http://127.0.0.1:8080; }
}
```

SSL 在宿主机或 CDN 层处理，容器不关心证书。

## 三层镜像与维护模式

镜像分三层（单 Dockerfile 多 target，基座改动自动进入上两层）：

| 层 | target | 内容 | 用途 |
|----|--------|------|------|
| ① 基座 | `base` | 系统组件（nginx/supervisor/postgresql/redis/curl）+ 全部服务配置 + 入口脚本 | 仅审计/缓存，不要直接 FROM |
| ② 生产 | `prod` | ① + 编译产物（api/admin-ui/user-ui） | **线上默认镜像**（compose 已锁定） |
| ③ 维护 | `maint` | ② + unzip/wget/vim/less/procps + /app 种子 | 排障临时用，不常驻生产 |

日常部署/重新部署不变（`deploy.sh` / `redeploy.sh` 默认构建 prod）。

### 维护模式（/app 直接映射宿主机编辑）

```bash
# 启动维护容器（生产同款服务 + 维护工具 + /app 映射到宿主机 ./app）
docker compose -f docker-compose.yml -f docker-compose.maint.yml up -d --build

# 在宿主机直接编辑 ./app 下的产物/脚本，改 API 产物后热生效：
docker compose -f docker-compose.yml -f docker-compose.maint.yml exec app supervisorctl restart api

# 排障完成，退回生产：
docker compose -f docker-compose.yml -f docker-compose.maint.yml down
docker compose up -d
```

注意事项：

- `/app` 被宿主机目录遮蔽，**首次启动为空时自动从镜像播种**（bootstrap）；已有内容绝不覆盖
- 版本升级需重新播种：`down` → 清空宿主机 `app/` 目录（先备份改动）→ `up`
- 维护容器与生产共用同一套 PostgreSQL/Redis 数据卷，改的是真实数据
- 维护工具（vim/wget 等）**严禁**加进生产镜像；`curl` 因 healthcheck 依赖保留在基座层

## Nginx 上传限制与静态文件

`nginx/default.conf` 顶部已预置 `client_max_body_size 128m;`（对应应用层 100MB 上传限制）。
**改上传大小、配置 admin/user 访问 API 静态文件（alias 替代软链）、上传目录卷持久化**，
完整步骤见框架文档：[`sb-framework/docs/AI_Nginx_Upload_Static.md`](../sb-framework/docs/AI_Nginx_Upload_Static.md)。

## 域名配置

在宿主机 Nginx 配置子域名转发到 Docker 容器：

```nginx
# admin.example.com → 管理端
server {
    listen 80;
    server_name admin.example.com;
    location / { proxy_pass http://127.0.0.1:8081; }
}

# example.com / www.example.com → 用户端
server {
    listen 80;
    server_name example.com www.example.com;
    location / { proxy_pass http://127.0.0.1:8080; }
}
```

SSL 在宿主机或 CDN 层处理，容器不关心证书。
