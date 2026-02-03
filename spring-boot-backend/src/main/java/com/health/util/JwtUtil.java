package com.health.util;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;

/**
 * JWT 工具类
 */
public class JwtUtil {

    private final SecretKey secretKey;

    public JwtUtil(String secret) {
        // 确保密钥长度足够（HS256 需要至少 256 位）
        if (secret.length() < 32) {
            throw new IllegalArgumentException("JWT 密钥长度必须至少 32 个字符");
        }
        this.secretKey = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
    }

    /**
     * 生成访问令牌
     */
    public String generateAccessToken(Long userId, String phone) {
        return generateToken(userId, phone, 7200L); // 2 小时
    }

    /**
     * 生成刷新令牌
     */
    public String generateRefreshToken(Long userId, String phone) {
        return generateToken(userId, phone, 604800L); // 7 天
    }

    /**
     * 生成令牌
     */
    private String generateToken(Long userId, String phone, Long expiration) {
        Map<String, Object> claims = new HashMap<>();
        claims.put("userId", userId);
        claims.put("phone", phone);

        Date now = new Date();
        Date expiryDate = new Date(now.getTime() + expiration * 1000);

        return Jwts.builder()
                .claims(claims)
                .subject(String.valueOf(userId))
                .issuedAt(now)
                .expiration(expiryDate)
                .signWith(secretKey)
                .compact();
    }

    /**
     * 从令牌中获取用户ID
     */
    public Long getUserIdFromToken(String token) {
        Claims claims = getClaimsFromToken(token);
        if (claims == null) {
            return null;
        }
        Object userId = claims.get("userId");
        if (userId instanceof Long) {
            return (Long) userId;
        } else if (userId instanceof Integer) {
            return ((Integer) userId).longValue();
        } else if (userId instanceof String) {
            return Long.valueOf((String) userId);
        }
        return null;
    }

    /**
     * 从令牌中获取手机号
     */
    public String getPhoneFromToken(String token) {
        Claims claims = getClaimsFromToken(token);
        return claims != null ? claims.get("phone", String.class) : null;
    }

    /**
     * 验证令牌是否有效
     */
    public boolean validateToken(String token) {
        try {
            Claims claims = getClaimsFromToken(token);
            return claims != null && !isTokenExpired(claims);
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * 获取令牌过期时间
     */
    public Date getExpirationDateFromToken(String token) {
        Claims claims = getClaimsFromToken(token);
        return claims != null ? claims.getExpiration() : null;
    }

    /**
     * 从令牌中获取 Claims
     */
    private Claims getClaimsFromToken(String token) {
        try {
            return Jwts.parser()
                    .verifyWith(secretKey)
                    .build()
                    .parseSignedClaims(token)
                    .getPayload();
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * 判断令牌是否过期
     */
    private boolean isTokenExpired(Claims claims) {
        Date expiration = claims.getExpiration();
        return expiration.before(new Date());
    }

    /**
     * 获取剩余过期时间（秒）
     */
    public Long getRemainingExpiration(String token) {
        Date expiration = getExpirationDateFromToken(token);
        if (expiration == null) {
            return 0L;
        }
        long remaining = (expiration.getTime() - System.currentTimeMillis()) / 1000;
        return Math.max(remaining, 0L);
    }
}
