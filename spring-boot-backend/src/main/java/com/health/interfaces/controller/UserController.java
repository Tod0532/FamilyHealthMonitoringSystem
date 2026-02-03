package com.health.interfaces.controller;

import com.health.interfaces.dto.UserVO;
import com.health.interfaces.response.ApiResponse;
import com.health.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.*;

/**
 * 用户控制器
 */
@Slf4j
@RestController
@RequiredArgsConstructor
@Tag(name = "用户管理", description = "用户信息查询与更新")
public class UserController {

    private final UserService userService;

    /**
     * 获取当前用户信息
     */
    @GetMapping("/user/info")
    @Operation(summary = "获取当前用户信息", description = "获取当前登录用户的详细信息")
    public ApiResponse<UserVO> getCurrentUser(
            @Parameter(description = "用户ID", required = true)
            @RequestHeader("X-User-Id") Long userId) {
        log.info("获取用户信息: userId={}", userId);
        UserVO userVO = userService.getUserById(userId);
        return ApiResponse.success(userVO);
    }

    /**
     * 根据ID获取用户信息
     */
    @GetMapping("/user/{id}")
    @Operation(summary = "根据ID获取用户信息", description = "根据用户ID查询用户信息")
    public ApiResponse<UserVO> getUserById(
            @Parameter(description = "用户ID", required = true)
            @PathVariable Long id) {
        log.info("根据ID获取用户信息: id={}", id);
        UserVO userVO = userService.getUserById(id);
        return ApiResponse.success(userVO);
    }
}
