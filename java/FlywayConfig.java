package com.lframework.xingyun.api.config;

import org.flywaydb.core.Flyway;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.flyway.FlywayMigrationInitializer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import javax.sql.DataSource;

/**
 * 多数据源 Flyway 配置 - 模板
 *
 * 适用场景:
 *   - 有 platform (平台库) 和 tenant (业务库) 两个独立数据库
 *   - 迁移文件分别放在 db/migration/platform/ 和 db/migration/tenant/
 *
 * 复用: 复制此文件到 api 模块 config 包, 调整 DataSource Qualifier 名
 */
@Configuration
public class FlywayConfig {

    private static final String PLATFORM = "classpath:db/migration/platform";
    private static final String TENANT = "classpath:db/migration/tenant";

    @Bean
    public FlywayMigrationInitializer platformFlywayInitializer(
            @Qualifier("platformDataSource") DataSource platformDataSource) {
        Flyway flyway = Flyway.configure()
                .dataSource(platformDataSource)
                .locations(PLATFORM)
                .baselineOnMigrate(true)
                .baselineVersion("1")
                .load();
        flyway.repair();
        return new FlywayMigrationInitializer(flyway);
    }

    @Bean
    public FlywayMigrationInitializer tenantFlywayInitializer(
            @Qualifier("tenantDataSource") DataSource tenantDataSource) {
        Flyway flyway = Flyway.configure()
                .dataSource(tenantDataSource)
                .locations(TENANT)
                .baselineOnMigrate(true)
                .baselineVersion("1")
                .load();
        flyway.repair();
        return new FlywayMigrationInitializer(flyway);
    }
}