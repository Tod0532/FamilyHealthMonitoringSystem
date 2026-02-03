package com.health;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * 最简化启动 - 验证H2配置
 */
@SpringBootApplication
public class HealthCenterApplication {
    public static void main(String[] args) {
        SpringApplication.run(HealthCenterApplication.class, args);
    }
}
