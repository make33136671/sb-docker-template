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
