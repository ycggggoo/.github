# 星云 ERP CI/CD 标准流程规范 v1.0

适用所有项目（后端 Java/Maven, 前端 Node），确保开发→测试→生产的代码流转一致。

## 一、分支策略

```
master ───────────────────────────→ 生产环境（永远可部署）
  ↑
  │  Pull Request + Code Review
  │
feature/<模块>-<描述> ──→ 功能开发 & 本地自测
  ↑
  │
hotfix/<描述> ──→ 紧急修复，完成后同时合入 master 和 feature 父分支
```

**规则**:
- **master** 是唯一真相源。只接受 PR 合并，不允许直接 push。
- **feature** 命名规范: `feature/<模块>-<简短描述>`, 如 `feature/crm-customer-pool`
- **hotfix** 从 master 切出, 修复后单独合并回 master 和对应的 feature 分支
- 每个 PR 必须有至少一人 review。小团队至少自己过一遍 diff 再合并。
- 合并方式: **fast-forward only** 或 **squash merge** (由 repo 设置决定)。禁止产生无意义的 merge commit。

## 二、环境策略

| 环境 | 触发方式 | 用途 |
|------|----------|------|
| **本地** | `docker compose up` (infra) + IDE 启动 | 开发调试 |
| **CI** | PR 触发: 编译 + 测试; master push: 构建镜像 | 自动化验证 |
| **生产** | master push 后 CD 自动部署 (或手动执行 deploy.sh) | 正式环境 |

- 单服务器情况下, CI 只做编译+测试+镜像构建, 部署由 CD job 或手动脚本控制
- 有 staging 服务器时, 增加 `develop` 分支自动部署测试环境

## 三、代码提交规范

```
<type>(<scope>): <简短描述>
```

- type: feat / fix / refactor / docs / style / test / chore / perf
- scope: 模块名, 如 crm / produce / sc / basedata / deploy
- 描述使用中文，一行不超过 72 字符

示例:
```
feat(crm): 新增线索导入功能
fix(sc): 修复收货单回显金额为0的问题
refactor(basedata): 供应商商品关联表独立为V1.30
```

## 四、CI/CD 流水线

```
│ ┌─────────────── Pull Request ───────────────────────────────────┐ │
│ │                                                                 │ │
│ │  ① Maven compile + test         ② Node build (前端)              │ │
│ │         ↓                              ↓                        │ │
│ │  [通过 / 失败]                   [通过 / 失败]                    │ │
│ │         ↓                              ↓                        │ │
│ │  通知 PR 评论区                    通知 PR 评论区                  │ │
│ │                                                                 │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│ ┌─────────────── Merge to master ─────────────────────────────────┐ │
│ │                                                                 │ │
│ │  ① Maven package               ② Docker build                  │ │
│ │         ↓                              ↓                        │ │
│ │  ③ Push 镜像到 GHCR             ④ SSH deploy to server           │ │
│ │         ↓                              ↓                        │ │
│ │  ⑤ Health check                ⑥ 失败 → 自动回滚到上一版         │ │
│ │                                                                 │ │
│ └─────────────────────────────────────────────────────────────────┘ │
```

## 五、镜像版本管理

每个镜像打三个 tag:

| Tag | 含义 | 用途 |
|-----|------|------|
| `:<git-sha>` | 唯一不可变镜像 | 回滚定位、审计追溯 |
| `:<日期>-<sha-short>` | 人工可读版本 | 手动回滚时使用 |
| `:latest` | 生产当前版本 | Docker compose 引用 |

回滚命令:
```bash
# 查看历史镜像
docker images xingyun-api --format '{{.Tag}}\t{{.CreatedAt}}'

# 回滚到指定版本
docker tag ghcr.io/ycggggoo/xingyun-api:20261016-fbff2947 xingyun-api:local
docker compose -f docker-compose.app.yml up -d xingyun-api
```

## 六、数据库迁移

使用 **Flyway** 自动管理。规则:

- 迁移文件位置: `src/main/resources/db/migration/<database>/V<version>__<描述>.sql`
- 每个迁移幂等 (使用 `CREATE TABLE IF NOT EXISTS` / `INSERT IGNORE`)
- 已执行的迁移**不可修改**。修改必须以新 V 文件追加
- 容器启动时自动执行迁移，无需人工介入

## 七、监控与告警

最小集:
- **健康检查**: `GET /actuator/health` → 200
- **容器状态**: `docker ps --filter "name=xingyun"`
- **日志**: `docker logs --tail 50 xingyun-api`

后续升级:
- Prometheus + Grafana 监控 JVM/CPU/内存
- 企业微信/钉钉告警通知

## 八、项目接入清单

新项目接入此体系只需做五件事:

- [ ] 1. 复制 `.github/workflows/*.yml` 到项目根目录
- [ ] 2. 引入 Flyway 依赖 + FlywayConfig.java
- [ ] 3. Dockerfile 使用本体系标准模板
- [ ] 4. 创建 `deploy/deploy.sh` 并配置服务器地址
- [ ] 5. 在 GitHub repo 设置 3 个 Secrets: `SSH_HOST`, `SSH_KEY`, `GHCR_PAT`