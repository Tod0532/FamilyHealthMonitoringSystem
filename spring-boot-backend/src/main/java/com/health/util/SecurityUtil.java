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

        // 注意：此处曾存在「开发环境允许从 X-User-Id 请求头获取用户ID」的兜底逻辑。
        // 该逻辑与 JwtAuthenticationFilter 中的同类分支共同构成了认证绕过漏洞
        // （无凭证即可冒充任意用户），已移除。调试请使用 dev profile 下的
        // app.debug.trust-user-id-header 开关，或正常登录获取 JWT。

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
