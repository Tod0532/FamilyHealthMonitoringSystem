package com.health.filter;

import com.health.service.impl.UserServiceImpl;
import com.health.util.JwtUtil;
import javax.servlet.FilterChain;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
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
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtUtil jwtUtil;

    private static final String USER_ID_ATTRIBUTE = "userId";
    private static final String USER_ID_HEADER = "X-User-Id";

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {

        // 提取令牌
        String token = extractToken(request);

        if (token != null && jwtUtil.validateToken(token)) {
            // 检查令牌是否在黑名单中
            if (UserServiceImpl.isTokenBlacklisted(token)) {
                log.warn("令牌已在黑名单中");
                SecurityContextHolder.clearContext();
            } else {
                // 从令牌中获取用户信息
                Long userId = jwtUtil.getUserIdFromToken(token);
                String phone = jwtUtil.getPhoneFromToken(token);

                if (userId != null) {
                    // 创建认证对象并存入SecurityContext
                    UsernamePasswordAuthenticationToken authentication =
                            new UsernamePasswordAuthenticationToken(
                                    userId,
                                    null,
                                    Collections.singletonList(new SimpleGrantedAuthority("ROLE_USER"))
                            );
                    SecurityContextHolder.getContext().setAuthentication(authentication);

                    // 将用户ID添加到请求属性，方便后续使用
                    request.setAttribute(USER_ID_ATTRIBUTE, userId);
                    // 同时也设置到请求头属性（用于Controller的@RequestHeader）
                    request.setAttribute(USER_ID_HEADER, userId);
                    log.debug("用户认证成功: userId={}, phone={}", userId, phone);
                }
            }
        } else {
            // 开发环境降级：如果没有JWT token，尝试从X-User-Id header获取
            String userIdHeader = request.getHeader(USER_ID_HEADER);
            if (userIdHeader != null) {
                try {
                    Long userId = Long.valueOf(userIdHeader);
                    // 创建认证对象并存入SecurityContext
                    UsernamePasswordAuthenticationToken authentication =
                            new UsernamePasswordAuthenticationToken(
                                    userId,
                                    null,
                                    Collections.singletonList(new SimpleGrantedAuthority("ROLE_USER"))
                            );
                    SecurityContextHolder.getContext().setAuthentication(authentication);

                    // 将用户ID添加到请求属性
                    request.setAttribute(USER_ID_ATTRIBUTE, userId);
                    request.setAttribute(USER_ID_HEADER, userId);
                    log.debug("用户认证成功: userId={}", userId);
                } catch (NumberFormatException e) {
                    log.warn("无效的X-User-Id header值: {}", userIdHeader);
                }
            }
        }

        filterChain.doFilter(request, response);
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
