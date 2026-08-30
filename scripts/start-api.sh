#!/bin/bash
set -e

export ASPNETCORE_ENVIRONMENT=Production
export ASPNETCORE_URLS=http://+:6010
export DbConfig__DbType=PostgreSQL
export DbConfig__Server=localhost
export DbConfig__Port=5432
export DbConfig__Database=${POSTGRES_DB:-sb_myapp}
export DbConfig__User=postgres
export DbConfig__Password=${POSTGRES_PASSWORD}
export CacheConfig__Provider=Redis
export "CacheConfig__Redis__Connection=localhost:6379"
export "CacheConfig__Redis__InstanceName=${PROJECT_NAME:-myapp}:"

echo "→ Waiting for PostgreSQL..."
until PGPASSWORD=${POSTGRES_PASSWORD} pg_isready -h 127.0.0.1 -U postgres -q 2>/dev/null; do
    sleep 1
done
echo "✓ PostgreSQL ready."

echo "→ Waiting for Redis..."
until redis-cli ping 2>/dev/null | grep -q PONG; do
    sleep 1
done
echo "✓ Redis ready."

cd /app/api
echo "→ Starting .NET API..."
exec dotnet "${APP_DLL_NAME:-MyApp.WebApi.dll}"
