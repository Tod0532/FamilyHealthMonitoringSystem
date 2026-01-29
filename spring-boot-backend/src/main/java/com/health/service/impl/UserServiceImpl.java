package com.health.service.impl;

import at.favre.lib.crypto.bcrypt.BCrypt;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.health.config.JwtProperties;
import com.health.domain.entity.User;
import com.health.domain.mapper.UserMapper;
import com.health.exception.BusinessException;
import com.health.exception.ErrorCode;
import com.health.interfaces.dto.*;
import com.health.service.UserService;
import com.health.util.JwtUtil;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.BeanUtils;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;

/**
 * 用户服务实现
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class UserServiceImpl implements UserService {

    private final UserMapper userMapper;
    private final JwtUtil jwtUtil;
    private final JwtProperties jwtProperties;
    private final RedisTemplate<String, Object> redisTemplate;

    private static final String SMS_CODE_KEY = "sms:code:";
    private static final String BLACKLIST_KEY = "token:blacklist:";

    @Override
    public AuthResponse register(RegisterRequest request) {
        // 1. 验证两次密码是否一致
        if (!request.getPassword().equals(request.getConfirmPassword())) {
            throw new BusinessException(ErrorCode.INVALID_PARAM, "两次密码不一致");
        }

        // 2. 检查手机号是否已注册
        User existUser = getUserByPhone(request.getPhone());
        if (existUser != null) {
            throw new BusinessException(ErrorCode.USER_ALREADY_EXISTS, "手机号已注册");
        }

        // 3. 验证短信验证码
        String smsKey = SMS_CODE_KEY + "register:" + request.getPhone();
        String savedCode = (String) redisTemplate.opsForValue().get(smsKey);
        if (savedCode == null) {
            throw new BusinessException(ErrorCode.INVALID_PARAM, "验证码已过期");
        }
        if (!savedCode.equals(request.getSmsCode())) {
            throw new BusinessException(ErrorCode.INVALID_PARAM, "验证码错误");
        }
        // 验证成功后删除验证码
        redisTemplate.delete(smsKey);

        // 4. 创建用户
        User user = new User();
        user.setPhone(request.getPhone());
        user.setPassword(BCrypt.withDefaults().hashToString(12, request.getPassword().toCharArray()));
        // 昵称默认为：健康用户 + 手机号后4位
        String defaultNickname = "健康用户" + request.getPhone().substring(Math.max(0, request.getPhone().length() - 4));
        user.setNickname(request.getNickname() != null ? request.getNickname() : defaultNickname);
        user.setGender(0);
        user.setStatus(0);
        user.setCreateTime(LocalDateTime.now());
        user.setUpdateTime(LocalDateTime.now());

        userMapper.insert(user);
        log.info("用户注册成功: userId={}, phone={}", user.getId(), user.getPhone());

        // 5. 生成令牌
        return generateAuthResponse(user);
    }

    @Override
    public AuthResponse login(LoginRequest request) {
        // 1. 查找用户
        User user = getUserByPhone(request.getPhone());
        if (user == null) {
            throw new BusinessException(ErrorCode.USER_NOT_FOUND, "用户不存在");
        }

        // 2. 验证密码
        boolean passwordMatch = BCrypt.verifyer().verify(request.getPassword().toCharArray(), user.getPassword()).verified;
        if (!passwordMatch) {
            throw new BusinessException(ErrorCode.INVALID_CREDENTIALS, "密码错误");
        }

        // 3. 检查账号状态
        if (user.getStatus() == 1) {
            throw new BusinessException(ErrorCode.ACCOUNT_DISABLED, "账号已被禁用");
        }

        // 4. 更新最后登录信息
        user.setLastLoginTime(LocalDateTime.now());
        userMapper.updateById(user);

        log.info("用户登录成功: userId={}, phone={}", user.getId(), user.getPhone());

        // 5. 生成令牌
        return generateAuthResponse(user);
    }

    @Override
    public AuthResponse refreshToken(String refreshToken) {
        // 1. 验证刷新令牌
        if (!jwtUtil.validateToken(refreshToken)) {
            throw new BusinessException(ErrorCode.INVALID_TOKEN, "刷新令牌无效");
        }

        // 2. 获取用户信息
        Long userId = jwtUtil.getUserIdFromToken(refreshToken);
        User user = userMapper.selectById(userId);
        if (user == null) {
            throw new BusinessException(ErrorCode.USER_NOT_FOUND, "用户不存在");
        }

        // 3. 检查账号状态
        if (user.getStatus() == 1) {
            throw new BusinessException(ErrorCode.ACCOUNT_DISABLED, "账号已被禁用");
        }

        // 4. 生成新令牌
        return generateAuthResponse(user);
    }

    @Override
    public void logout(String token) {
        if (token != null && jwtUtil.validateToken(token)) {
            // 将令牌加入黑名单
            Long expiration = jwtUtil.getRemainingExpiration(token);
            if (expiration > 0) {
                String userId = jwtUtil.getUserIdFromToken(token).toString();
                redisTemplate.opsForValue().set(BLACKLIST_KEY + token, userId, expiration, java.util.concurrent.TimeUnit.SECONDS);
            }
        }
        log.info("用户登出成功");
    }

    @Override
    public UserVO getUserById(Long userId) {
        User user = userMapper.selectById(userId);
        if (user == null) {
            throw new BusinessException(ErrorCode.USER_NOT_FOUND, "用户不存在");
        }
        return toUserVO(user);
    }

    @Override
    public User getUserByPhone(String phone) {
        LambdaQueryWrapper<User> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(User::getPhone, phone);
        return userMapper.selectOne(wrapper);
    }

    /**
     * 生成认证响应
     */
    private AuthResponse generateAuthResponse(User user) {
        String accessToken = jwtUtil.generateAccessToken(user.getId(), user.getPhone());
        String refreshToken = jwtUtil.generateRefreshToken(user.getId(), user.getPhone());

        AuthResponse.UserInfo userInfo = AuthResponse.UserInfo.builder()
                .id(user.getId())
                .phone(user.getPhone())
                .nickname(user.getNickname())
                .avatar(user.getAvatar())
                .build();

        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .tokenType(jwtProperties.getTokenPrefix())
                .expiresIn(jwtProperties.getExpiration())
                .userInfo(userInfo)
                .build();
    }

    /**
     * 转换为 UserVO
     */
    private UserVO toUserVO(User user) {
        return UserVO.builder()
                .id(user.getId())
                .phone(user.getPhone())
                .nickname(user.getNickname())
                .avatar(user.getAvatar())
                .gender(user.getGender())
                .birthday(user.getBirthday())
                .status(user.getStatus())
                .lastLoginTime(user.getLastLoginTime())
                .createTime(user.getCreateTime())
                .build();
    }
}
