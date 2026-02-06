package com.health.config;

import com.health.interfaces.response.ApiResponse;
import com.health.util.JwtUtil;
import com.fasterxml.jackson.databind.ObjectMapper;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;

import java.io.IOException;
import java.util.Arrays;

/**
 * 角色验证拦截器
 * 检查请求的用户角色是否满足 @RequireRole 注解的要求
 */
@Slf4j
@Component
public class RoleInterceptor implements HandlerInterceptor {

    private final JwtUtil jwtUtil;
    private final ObjectMapper objectMapper;

    public RoleInterceptor(JwtUtil jwtUtil, ObjectMapper objectMapper) {
        this.jwtUtil = jwtUtil;
        this.objectMapper = objectMapper;
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler)
            throws Exception {

        // 只处理方法处理器
        if (!(handler instanceof HandlerMethod)) {
            return true;
        }

        HandlerMethod handlerMethod = (HandlerMethod) handler;

        // 检查方法上是否有 @RequireRole 注解
        RequireRole methodAnnotation = handlerMethod.getMethodAnnotation(RequireRole.class);

        // 如果方法上没有，检查类级别注解
        if (methodAnnotation == null) {
            methodAnnotation = handlerMethod.getBeanType().getAnnotation(RequireRole.class);
        }

        // 没有注解则放行
        if (methodAnnotation == null) {
            return true;
        }

        // 提取Token
        String token = extractToken(request);
        if (token == null) {
            log.warn("访问受限资源未提供Token: uri={}", request.getRequestURI());
            sendErrorResponse(response, 401, "未提供认证令牌");
            return false;
        }

        // 验证Token有效性
        if (!jwtUtil.validateToken(token)) {
            log.warn("Token无效或已过期: uri={}", request.getRequestURI());
            sendErrorResponse(response, 401, "令牌无效或已过期");
            return false;
        }

        // 获取用户角色
        String userRole = jwtUtil.getRoleFromToken(token);
        if (userRole == null) {
            userRole = "USER"; // 默认角色
        }
        final String finalUserRole = userRole;

        // 检查角色是否匹配
        String[] requiredRoles = methodAnnotation.value();
        boolean hasPermission = Arrays.stream(requiredRoles)
                .anyMatch(role -> role.equalsIgnoreCase(finalUserRole));

        if (!hasPermission) {
            log.warn("用户角色权限不足: uri={}, userRole={}, requiredRoles={}",
                    request.getRequestURI(), userRole, Arrays.toString(requiredRoles));
            sendErrorResponse(response, 403, "权限不足，需要 " + String.join(" 或 ", requiredRoles) + " 角色");
            return false;
        }

        log.debug("角色验证通过: uri={}, userRole={}", request.getRequestURI(), userRole);
        return true;
    }

    /**
     * 从请求头中提取令牌
     */
    private String extractToken(HttpServletRequest request) {
        String bearerToken = request.getHeader("Authorization");
        if (bearerToken != null && bearerToken.startsWith("Bearer ")) {
            return bearerToken.substring(7);
        }
        return null;
    }

    /**
     * 发送错误响应
     */
    private void sendErrorResponse(HttpServletResponse response, int status, String message) throws IOException {
        response.setStatus(status);
        response.setContentType("application/json;charset=UTF-8");
        ApiResponse<Void> apiResponse = ApiResponse.fail(status, message);
        response.getWriter().write(objectMapper.writeValueAsString(apiResponse));
    }
}
