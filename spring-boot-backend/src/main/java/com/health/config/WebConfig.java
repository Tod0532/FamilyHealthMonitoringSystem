package com.health.config;

import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * Web MVC 配置类
 * 配置拦截器、跨域等Web相关设置
 */
@Configuration
@RequiredArgsConstructor
public class WebConfig implements WebMvcConfigurer {

    private final RoleInterceptor roleInterceptor;

    /**
     * 注册拦截器
     */
    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(roleInterceptor)
                .addPathPatterns("/api/**")  // 拦截所有API请求
                .excludePathPatterns(       // 排除不需要权限验证的路径
                        "/api/auth/login",      // 登录接口
                        "/api/auth/register",   // 注册接口
                        "/api/test/**",         // 测试接口
                        "/swagger-ui/**",       // Swagger UI
                        "/v3/api-docs/**",      // API 文档
                        "/knife4j/**",          // Knife4j 文档
                        "/doc.html",            // API 文档页面
                        "/favicon.ico",         // 网站图标
                        "/error"                // 错误页面
                );
    }
}
