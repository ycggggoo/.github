   # ycggggoo/.github

   跨项目可复用的 CI/CD 标准件。

   ## 使用方式

   在任何 `ycggggoo` 仓库下引用:

   ```yaml
   jobs:
     build:
       uses: ycggggoo/.github/.github/workflows/docker-build-push.yml@master
       with:
         image-name: ycggggoo/项目名-api
         java-version: '21'
       secrets:
         GHCR_PAT: ${{ secrets.GHCR_PAT }}
 ```

 文件说明

 ┌─────────────────────────────────┬────────────────────────────┐
 │ 路径                            │ 用途                       │
 ├─────────────────────────────────┼────────────────────────────┤
 │ workflows/java-maven-ci.yml     │ Java Maven 编译+测试       │
 ├─────────────────────────────────┼────────────────────────────┤
 │ workflows/docker-build-push.yml │ 构建 Docker 镜像推 GHCR    │
 ├─────────────────────────────────┼────────────────────────────┤
 │ workflows/frontend-node-ci.yml  │ 前端 pnpm 构建推 GHCR      │
 ├─────────────────────────────────┼────────────────────────────┤
 │ workflows/ssh-deploy.yml        │ SSH 部署+健康检查+自动回滚 │
 ├─────────────────────────────────┼────────────────────────────┤
 │ deploy/deploy.sh                │ 通用手动部署脚本           │
 ├─────────────────────────────────┼────────────────────────────┤
 │ docker/Dockerfile.api.template  │ 标准 Java Dockerfile       │
 ├─────────────────────────────────┼────────────────────────────┤
 │ docker/Dockerfile.web.template  │ 标准前端 Dockerfile        │
 ├─────────────────────────────────┼────────────────────────────┤
 │ java/FlywayConfig.java          │ 多数据源 Flyway 配置       │
 ├─────────────────────────────────┼────────────────────────────┤
 │ docs/ci-cd-standard.md          │ CI/CD 流程规范             │
 ├─────────────────────────────────┼────────────────────────────┤
 │ EOF                             │                            │
 └─────────────────────────────────┴────────────────────────────┘
