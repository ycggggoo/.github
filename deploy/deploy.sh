#!/bin/bash
# 标准部署脚本 - 适用于任何项目
# 用法: ./deploy.sh [branch] [--no-push]
# 默认部署 master 分支
set -euo pipefail

BRANCH=${1:-master}
NO_PUSH=${2:-}
PROJECT=$(basename "$(git rev-parse --show-toplevel)")
TAG=$(date +%Y%m%d-%H%M%S)-$(git rev-parse --short HEAD)
SERVER_HOST="${DEPLOY_HOST:-}"
SERVER_DIR="${DEPLOY_DIR:-/opt/app}"
API_IMAGE="${DOCKER_API_IMAGE:-${PROJECT}-api}"
WEB_IMAGE="${DOCKER_WEB_IMAGE:-${PROJECT}-web}"
DOCKERFILE_API="${DOCKERFILE_API:-deploy/Dockerfile.api}"
DOCKERFILE_WEB="${DOCKERFILE_WEB:-deploy/Dockerfile.web}"

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

echo "============================================"
echo " Deploy: ${PROJECT}  (branch: ${BRANCH})"
echo " Tag:    ${TAG}"
echo "============================================"

# ─── 1. 推送代码 ──────────────────────────────────
if [ "${NO_PUSH}" != "--no-push" ]; then
  echo "=== 1/6 Push code to GitHub ==="
  git push origin "${BRANCH}" || fail "git push failed"
  ok "Code pushed"
else
  echo "=== 1/6 Skip push (--no-push) ==="
fi

# ─── 2. 服务器拉取 ───────────────────────────────
echo "=== 2/6 Pull on server ==="
ssh "${SERVER_HOST}" "cd ${SERVER_DIR} && git pull origin ${BRANCH}" || fail "git pull on server failed"
ok "Server synced"

# ─── 3. 检测新 SQL ───────────────────────────────
echo "=== 3/6 Check new migrations ==="
NEW_SQL=$(ssh "${SERVER_HOST}" "cd ${SERVER_DIR} && git diff --name-only HEAD~3..HEAD -- '*/db/migration/*.sql' 2>/dev/null" || echo "")
if [ -n "${NEW_SQL}" ]; then
  echo "⚠️  New migration files detected:"
  echo "${NEW_SQL}"
  echo ""
  echo "Flyway will auto-run them at startup. No manual action needed."
else
  ok "No new migrations"
fi

# ─── 4. 构建镜像 ──────────────────────────────────
echo "=== 4/6 Build Docker images ==="

# 后端
if [ -f "${DOCKERFILE_API}" ] || [ -f "deploy/Dockerfile.api" ]; then
  echo "--- Building ${API_IMAGE}:${TAG} ---"
  docker build -f "${DOCKERFILE_API}" -t "${API_IMAGE}:${TAG}" . || fail "API build failed"
  docker tag "${API_IMAGE}:${TAG}" "${API_IMAGE}:local"
  ok "API image: ${API_IMAGE}:${TAG}"
fi

# 前端
if [ -f "${DOCKERFILE_WEB}" ] || [ -f "deploy/Dockerfile.web" ]; then
  echo "--- Building ${WEB_IMAGE}:${TAG} ---"
  docker build -f "${DOCKERFILE_WEB}" -t "${WEB_IMAGE}:${TAG}" . || fail "Web build failed"
  docker tag "${WEB_IMAGE}:${TAG}" "${WEB_IMAGE}:local"
  ok "Web image: ${WEB_IMAGE}:${TAG}"
fi

# ─── 5. 重启容器 ──────────────────────────────────
echo "=== 5/6 Restart containers ==="
docker compose -f docker-compose.app.yml up -d --force-recreate || fail "Container restart failed"
ok "Containers started"

# ─── 6. 健康检查 ──────────────────────────────────
echo "=== 6/6 Health check ==="
for i in 1 2 3 4 5 6 7 8 9 10; do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 5 http://localhost:8080/actuator/health 2>/dev/null || echo "000")
  if [ "${HTTP_CODE}" = "200" ]; then
    ok "Health check passed (attempt $i)"
    break
  fi
  if [ "${i}" = "10" ]; then
    fail "Health check FAILED after 10 attempts"
  fi
  sleep 10
done

# ─── 完成 ─────────────────────────────────────────
echo ""
echo "============================================"
echo " Deploy SUCCESS"
echo " Version: ${TAG}"
echo "============================================"
echo ""
echo "Rollback command:"
echo "  docker tag ${API_IMAGE}:<previous-tag> ${API_IMAGE}:local"
echo "  docker compose -f docker-compose.app.yml up -d"
echo ""
echo "Available images:"
docker images "${API_IMAGE}" --format "  {{.Tag}}\t{{.CreatedAt}}" 2>/dev/null || true