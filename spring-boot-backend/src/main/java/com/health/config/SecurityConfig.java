package com.health.config;

import com.health.filter.JwtAuthenticationFilter;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.security.config.annotation.method.configuration.EnableGlobalMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.Arrays;
import java.util.List;

/**
 * Spring Security 配置
 */
@Configuration
@EnableWebSecurity
@EnableGlobalMethodSecurity(prePostEnabled = true)
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtAuthenticationFilter;

    /**
     * 允许的CORS源配置（逗号分隔）
     * 开发环境：允许本地调试地址
     * 生产环境：应配置为实际的前端域名
     */
    @Value("${app.cors.allowed-origins:http://localhost:3000,http://localhost:8080,http://127.0.0.1:3000,http://127.0.0.1:8080}")
    private String[] allowedOrigins;

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                // 禁用CSRF（使用JWT时不需要）
                .csrf().disable()

                // 配置会话管理为无状态
                .sessionManagement()
                    .sessionCreationPolicy(SessionCreationPolicy.STATELESS)
                .and()

                // 配置授权规则
                .authorizeRequests()
                        // 公开访问的端点
                        .antMatchers(
                                "/auth/**",
                                "/knife4j/**",
                                "/doc.html",
                                "/swagger-ui/**",
                                "/v3/api-docs/**",
                                "/favicon.ico",
                                "/error"
                        ).permitAll()
                        // 其他所有请求需要认证
                        .anyRequest().authenticated()
                .and()

                // 配置CORS
                .cors()
                    .configurationSource(corsConfigurationSource())
                .and()

                // 添加JWT过滤器
                .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    /**
     * CORS配置源
     * 使用配置文件中定义的允许源，提高安全性
     */
    private CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();

        // 从配置读取允许的源（避免使用通配符提高安全性）
        configuration.setAllowedOrigins(Arrays.asList(allowedOrigins));

        // 允许的请求头
        configuration.setAllowedHeaders(List.of("*"));

        // 允许的请求方法
        configuration.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"));

        // 允许携带凭证
        configuration.setAllowCredentials(true);

        // 预检请求缓存时间（秒）
        configuration.setMaxAge(3600L);

        // 暴露的响应头（允许前端访问）
        configuration.setExposedHeaders(Arrays.asList("Authorization", "Content-Type", "X-Total-Count"));

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);

        return source;
    }
}
