package com.health.config;

import com.health.util.JwtUtil;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * JWT 配置类
 */
@Configuration
public class JwtConfig {

    @Bean
    public JwtUtil jwtUtil(JwtProperties jwtProperties) {
        return new JwtUtil(jwtProperties.getSecret());
    }
}
