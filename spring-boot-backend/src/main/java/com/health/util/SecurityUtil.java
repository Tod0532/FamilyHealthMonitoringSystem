package com.health.util;

import com.health.exception.BusinessException;
import com.health.exception.ErrorCode;
import javax.servlet.http.HttpServletRequest;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

/**
 * 安全工具类
 */
public class SecurityUtil {

    private static final String USER_ID_ATTRIBUTE = "userId";

    /**
     * 从请求中获取用户ID
     * 优先从SecurityContext获取，其次从request属性获取
     */
    public static Long getUserId(HttpServletRequest request) {
        // 尝试从SecurityContext获取
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication != null && authentication.isAuthenticated()) {
            Object principal = authentication.getPrincipal();
            if (principal instanceof Long userId) {
                return userId;
            }
        }

        // 尝试从request属性获取（由JwtAuthenticationFilter设置）
        Object userIdAttr = request.getAttribute(USER_ID_ATTRIBUTE);
        if (userIdAttr instanceof Long userId) {
            return userId;
        }

        // 开发环境：允许从header获取用于测试
        String userIdHeader = request.getHeader("X-User-Id");
        if (userIdHeader != null) {
            try {
                return Long.valueOf(userIdHeader);
            } catch (NumberFormatException e) {
                // 忽略
            }
        }

        throw new BusinessException(ErrorCode.UNAUTHORIZED, "用户未登录或令牌已过期");
    }

    /**
     * 从SecurityContext获取用户ID
     */
    public static Long getCurrentUserId() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication != null && authentication.isAuthenticated()) {
            Object principal = authentication.getPrincipal();
            if (principal instanceof Long userId) {
                return userId;
            }
        }
        throw new BusinessException(ErrorCode.UNAUTHORIZED, "用户未登录");
    }
}
