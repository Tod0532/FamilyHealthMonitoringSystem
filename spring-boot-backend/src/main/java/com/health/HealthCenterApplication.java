package com.health;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.transaction.annotation.EnableTransactionManagement;

/**
 * 家庭健康中心APP - 后端应用入口
 *
 * @author 开发团队
 * @since 1.0.0
 */
@SpringBootApplication
@EnableCaching
@EnableAsync
@EnableTransactionManagement
public class HealthCenterApplication {

    public static void main(String[] args) {
        SpringApplication.run(HealthCenterApplication.class, args);
    }
}
