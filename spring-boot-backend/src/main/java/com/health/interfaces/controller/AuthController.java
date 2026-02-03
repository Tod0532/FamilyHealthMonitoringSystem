package com.health.interfaces.controller;

import com.health.interfaces.dto.AuthResponse;
import com.health.interfaces.dto.ChangePasswordRequest;
import com.health.interfaces.dto.LoginRequest;
import com.health.interfaces.dto.RegisterRequest;
import com.health.interfaces.response.ApiResponse;
import com.health.service.UserService;
import com.health.util.JwtUtil;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import javax.servlet.http.HttpServletRequest;
import javax.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.*;

/**
 * 认证控制器
 */
@Slf4j
@RestController
@RequiredArgsConstructor
@Tag(name = "认证管理", description = "用户注册、登录、令牌管理")
public class AuthController {

    private final UserService userService;
    private final JwtUtil jwtUtil;

    /**
     * 用户注册
     */
    @PostMapping("/auth/register")
    @Operation(summary = "用户注册", description = "通过手机号和密码注册新用户")
    public ApiResponse<AuthResponse> register(@Valid @RequestBody RegisterRequest request) {
        log.info("用户注册请求: phone={}", request.getPhone());
        AuthResponse response = userService.register(request);
        return ApiResponse.success(response);
    }

    /**
     * 用户登录
     */
    @PostMapping("/auth/login")
    @Operation(summary = "用户登录", description = "通过手机号和密码登录")
    public ApiResponse<AuthResponse> login(@Valid @RequestBody LoginRequest request) {
        log.info("用户登录请求: phone={}", request.getPhone());
        AuthResponse response = userService.login(request);
        return ApiResponse.success(response);
    }

    /**
     * 刷新令牌
     */
    @PostMapping("/auth/refresh")
    @Operation(summary = "刷新令牌", description = "使用刷新令牌获取新的访问令牌")
    public ApiResponse<AuthResponse> refresh(@RequestParam String refreshToken) {
        log.info("刷新令牌请求");
        AuthResponse response = userService.refreshToken(refreshToken);
        return ApiResponse.success(response);
    }

    /**
     * 用户登出
     */
    @PostMapping("/auth/logout")
    @Operation(summary = "用户登出", description = "退出登录，使当前令牌失效")
    public ApiResponse<Void> logout(HttpServletRequest request) {
        String token = extractToken(request);
        userService.logout(token);
        return ApiResponse.success();
    }

    /**
     * 修改密码
     */
    @PostMapping("/auth/change-password")
    @Operation(summary = "修改密码", description = "用户修改登录密码")
    public ApiResponse<Void> changePassword(
            @Valid @RequestBody ChangePasswordRequest request,
            HttpServletRequest httpRequest) {
        // 从请求头中获取用户ID
        String userIdHeader = httpRequest.getAttribute("X-User-Id") != null
                ? httpRequest.getAttribute("X-User-Id").toString()
                : null;

        if (userIdHeader == null) {
            // 如果请求头中没有，尝试从Token中获取
            String token = extractToken(httpRequest);
            if (token != null) {
                Long userId = jwtUtil.getUserIdFromToken(token);
                if (userId != null) {
                    userIdHeader = userId.toString();
                }
            }
        }

        if (userIdHeader == null) {
            return ApiResponse.error(401, "用户未登录");
        }

        Long userId = Long.valueOf(userIdHeader);
        userService.changePassword(userId, request.getOldPassword(), request.getNewPassword());
        return ApiResponse.success();
    }

    /**
     * 从请求头提取令牌
     */
    private String extractToken(HttpServletRequest request) {
        String bearerToken = request.getHeader("Authorization");
        if (bearerToken != null && bearerToken.startsWith("Bearer ")) {
            return bearerToken.substring(7);
        }
        return null;
    }
}
