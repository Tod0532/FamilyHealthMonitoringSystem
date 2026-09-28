package com.health.filter;

import com.health.config.DebugAuthProperties;
import com.health.service.impl.UserServiceImpl;
import com.health.util.JwtUtil;

import javax.servlet.FilterChain;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Collections;

/**
 * JWT 认证过滤器
 *
 * <p><b>安全说明</b>：本过滤器是系统唯一的身份来源。只有通过签名与有效期校验的
 * JWT 才会建立认证上下文。</p>
 *
 * <p>早期版本存在一个无条件的「开发环境降级」分支：无有效 JWT 时直接信任
 * {@code X-User-Id} 请求头并建立认证。这是一处严重的认证绕过漏洞（生产环境同样
 * 生效，任何人可冒充任意用户）。现已改为由 {@link DebugAuthProperties} 显式门控，
 * 且该配置 Bean 仅在 dev profile 下存在、默认关闭。</p>
 */
@Slf4j
@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtUtil jwtUtil;
    private final ObjectProvider<DebugAuthProperties> debugAuthPropertiesProvider;

    private static final String USER_ID_ATTRIBUTE = "userId";

    /**
     * 构造函数注入。
     *
     * <p>使用 {@link ObjectProvider} 而非直接注入 {@link DebugAuthProperties}，
     * 因为该 Bean 带 {@code @Profile("dev")} 与 {@code @ConditionalOnProperty}，
     * 在生产环境中根本不存在 —— 直接注入会导致启动失败。</p>
     */
    public JwtAuthenticationFilter(JwtUtil jwtUtil,
                                   ObjectProvider<DebugAuthProperties> debugAuthPropertiesProvider) {
        this.jwtUtil = jwtUtil;
        this.debugAuthPropertiesProvider = debugAuthPropertiesProvider;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {

        String token = extractToken(request);

        if (token != null && jwtUtil.validateToken(token)) {
            // 正常路径：JWT 有效
            if (UserServiceImpl.isTokenBlacklisted(token)) {
                log.warn("令牌已在黑名单中: uri={}", request.getRequestURI());
                SecurityContextHolder.clearContext();
            } else {
                Long userId = jwtUtil.getUserIdFromToken(token);
                if (userId != null) {
                    authenticate(request, userId);
                    log.debug("用户认证成功: userId={}", userId);
                }
            }
        } else if (isUserHeaderTrustEnabled()) {
            // 调试旁路：仅 dev profile 且显式开启 app.debug.trust-user-id-header=true 时可用
            String userIdHeader = request.getHeader("X-User-Id");
            if (StringUtils.hasText(userIdHeader)) {
                try {
                    Long userId = Long.valueOf(userIdHeader);
                    authenticate(request, userId);
                    log.warn("【调试开关已开启】信任 X-User-Id 头完成认证: userId={}, uri={}",
                            userId, request.getRequestURI());
                } catch (NumberFormatException e) {
                    log.warn("无效的X-User-Id header值: {}", userIdHeader);
                }
            }
        }

        filterChain.doFilter(request, response);
    }

    /**
     * 是否允许信任 X-User-Id 头（仅本地调试）。
     *
     * <p>生产环境中 {@link DebugAuthProperties} Bean 不存在，此方法恒返回 false。</p>
     */
    private boolean isUserHeaderTrustEnabled() {
        DebugAuthProperties props = debugAuthPropertiesProvider.getIfAvailable();
        return props != null && props.isTrustUserIdHeader();
    }

    /**
     * 建立认证上下文，并写入 request attribute 供 Controller 读取。
     *
     * <p>{@code userId} 属性是 Controller 获取当前用户身份的唯一推荐方式
     * （配合 {@code @RequestAttribute("userId")}），不再使用 {@code @RequestHeader}。</p>
     */
    private void authenticate(HttpServletRequest request, Long userId) {
        UsernamePasswordAuthenticationToken authentication =
                new UsernamePasswordAuthenticationToken(
                        userId,
                        null,
                        Collections.singletonList(new SimpleGrantedAuthority("ROLE_USER"))
                );
        SecurityContextHolder.getContext().setAuthentication(authentication);
        request.setAttribute(USER_ID_ATTRIBUTE, userId);
    }

    /**
     * 从请求头中提取令牌
     */
    private String extractToken(HttpServletRequest request) {
        String bearerToken = request.getHeader("Authorization");
        if (StringUtils.hasText(bearerToken) && bearerToken.startsWith("Bearer ")) {
            return bearerToken.substring(7);
        }
        return null;
    }
}
