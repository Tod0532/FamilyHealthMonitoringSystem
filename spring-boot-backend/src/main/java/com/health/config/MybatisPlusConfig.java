package com.health.config;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.context.annotation.Configuration;

/**
 * MyBatis-Plus 配置
 */
@Configuration
@MapperScan("com.health.domain.mapper")
public class MybatisPlusConfig {
    // 暂时使用默认配置，不添加任何拦截器
}
