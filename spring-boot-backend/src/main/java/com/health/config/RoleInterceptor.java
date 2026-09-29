package com.health.config;

import com.health.domain.entity.User;
import com.health.domain.mapper.UserMapper;
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
 *
 * <p>重要说明：本项目同时存在两套「角色」概念，必须区分：</p>
 * <ul>
 *   <li>全局角色 user.role：ADMIN / USER / GUEST，登录时写入 JWT 的 role 声明</li>
 *   <li>家庭角色 user.familyRole：admin / member，表示在家里的身份</li>
 * </ul>
 *
 * <p>而 {@code @RequireRole("ADMIN")} 标注的接口（家庭成员增删改、预警规则增删改启用）
 * 在业务语义上要求的是「家庭管理员」。此前这里只比对全局角色，导致：</p>
 * <pre>
 *   后注册的普通用户（全局 role=USER）即使自己创建了家庭、是该家庭的管理员，
 *   调用这些接口依然恒返回 403。
 *   实测：用户 B role=USER / familyRole=admin → POST /api/members → 403；
 *        种子用户 role=ADMIN / familyRole=admin → POST /api/members → 200。
 * </pre>
 * <p>即「家庭成员管理」和「预警规则配置」对普通用户完全不可用。
 * 现修正为：全局 ADMIN <b>或</b> 家庭管理员，任一满足即通过。</p>
 */
@Slf4j
@Component
public class RoleInterceptor implements HandlerInterceptor {

    private final JwtUtil jwtUtil;
    private final ObjectMapper objectMapper;
    private final UserMapper userMapper;

    public RoleInterceptor(JwtUtil jwtUtil, ObjectMapper objectMapper, UserMapper userMapper) {
        this.jwtUtil = jwtUtil;
        this.objectMapper = objectMapper;
        this.userMapper = userMapper;
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

        // 获取全局角色
        String userRole = jwtUtil.getRoleFromToken(token);
        if (userRole == null) {
            userRole = "USER"; // 默认角色
        }
        final String finalUserRole = userRole;

        String[] requiredRoles = methodAnnotation.value();
        boolean hasPermission = Arrays.stream(requiredRoles)
                .anyMatch(role -> role.equalsIgnoreCase(finalUserRole));

        // 兜底：要求 ADMIN 时，家庭管理员同样放行
        // （@RequireRole("ADMIN") 在这些接口上的真实语义是「家庭管理员」）
        if (!hasPermission && Arrays.stream(requiredRoles).anyMatch(role -> role.equalsIgnoreCase("ADMIN"))) {
            Long userId = jwtUtil.getUserIdFromToken(token);
            if (isFamilyAdmin(userId)) {
                hasPermission = true;
                log.debug("家庭管理员放行: uri={}, userId={}", request.getRequestURI(), userId);
            }
        }

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
     * 该用户是否为某个家庭的管理员
     */
    private boolean isFamilyAdmin(Long userId) {
        if (userId == null) {
            return false;
        }
        User user = userMapper.selectById(userId);
        return user != null
                && user.getFamilyId() != null
                && "admin".equalsIgnoreCase(user.getFamilyRole());
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
