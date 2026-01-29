package com.health.service;

import com.health.domain.entity.User;
import com.health.interfaces.dto.AuthResponse;
import com.health.interfaces.dto.LoginRequest;
import com.health.interfaces.dto.RegisterRequest;
import com.health.interfaces.dto.UserVO;

/**
 * 用户服务接口
 */
public interface UserService {

    /**
     * 用户注册
     */
    AuthResponse register(RegisterRequest request);

    /**
     * 用户登录
     */
    AuthResponse login(LoginRequest request);

    /**
     * 刷新令牌
     */
    AuthResponse refreshToken(String refreshToken);

    /**
     * 用户登出
     */
    void logout(String token);

    /**
     * 根据ID获取用户信息
     */
    UserVO getUserById(Long userId);

    /**
     * 根据手机号获取用户
     */
    User getUserByPhone(String phone);
}
