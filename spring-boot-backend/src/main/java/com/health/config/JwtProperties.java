package com.health.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * JWT 配置属性
 */
@Data
@Component
@ConfigurationProperties(prefix = "jwt")
public class JwtProperties {

    /**
     * 密钥（生产环境应从环境变量读取）
     */
    private String secret = "health-center-secret-key-change-in-production";

    /**
     * 访问令牌有效期（秒），默认 24 小时
     */
    private Long expiration = 86400L;

    /**
     * 刷新令牌有效期（秒），默认 7 天
     */
    private Long refreshExpiration = 604800L;

    /**
     * 令牌前缀
     */
    private String tokenPrefix = "Bearer ";

    /**
     * 令牌头部名称
     */
    private String headerName = "Authorization";
}
