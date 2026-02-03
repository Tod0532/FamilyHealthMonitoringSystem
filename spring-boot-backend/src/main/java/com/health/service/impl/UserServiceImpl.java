package com.health.service.impl;

import at.favre.lib.crypto.bcrypt.BCrypt;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.health.config.JwtProperties;
import com.health.domain.entity.User;
import com.health.domain.mapper.UserMapper;
import com.health.exception.BusinessException;
import com.health.exception.ErrorCode;
import com.health.interfaces.dto.AuthResponse;
import com.health.interfaces.dto.ChangePasswordRequest;
import com.health.interfaces.dto.LoginRequest;
import com.health.interfaces.dto.RegisterRequest;
import com.health.interfaces.dto.UserVO;
import com.health.service.UserService;
import com.health.util.JwtUtil;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.BeanUtils;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;

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

    // Redis Key 前缀
    private static final String TOKEN_BLACKLIST_KEY_PREFIX = "token:blacklist:";
    private static final String SMS_CODE_KEY_PREFIX = "sms:code:";

    // 临时使用内存存储（开发环境，Redis不可用时降级）
    private static final ConcurrentHashMap<String, String> SMS_CODE_STORE = new ConcurrentHashMap<>();
    private static final ConcurrentHashMap<String, Long> TOKEN_BLACKLIST = new ConcurrentHashMap<>();

    @Override
    @Transactional(rollbackFor = Exception.class)
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

        // 3. 跳过短信验证码验证（开发环境）
        // TODO: 生产环境需要接入短信服务

        // 4. 创建用户
        User user = new User();
        user.setPhone(request.getPhone());
        user.setPassword(BCrypt.withDefaults().hashToString(12, request.getPassword().toCharArray()));
        // 昵称默认为：健康用户 + 手机号后4位
        String defaultNickname = "健康用户" + request.getPhone().substring(Math.max(0, request.getPhone().length() - 4));
        user.setNickname(request.getNickname() != null ? request.getNickname() : defaultNickname);
        user.setGender(null);  // 用户注册时性别可选
        user.setStatus(1);  // 正常状态
        user.setCreateTime(LocalDateTime.now());
        user.setUpdateTime(LocalDateTime.now());

        userMapper.insert(user);
        log.info("用户注册成功: userId={}, phone={}", user.getId(), user.getPhone());

        // 5. 生成令牌
        return generateAuthResponse(user);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
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
        if (user.getStatus() == 0) {
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
    @Transactional(rollbackFor = Exception.class)
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
        if (user.getStatus() == 0) {
            throw new BusinessException(ErrorCode.ACCOUNT_DISABLED, "账号已被禁用");
        }

        // 4. 生成新令牌
        return generateAuthResponse(user);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void logout(String token) {
        if (token != null && jwtUtil.validateToken(token)) {
            // 将令牌加入黑名单（使用Redis持久化存储）
            Long expiration = jwtUtil.getRemainingExpiration(token);
            if (expiration > 0) {
                try {
                    // 使用Redis存储，自动过期
                    String redisKey = TOKEN_BLACKLIST_KEY_PREFIX + token;
                    redisTemplate.opsForValue().set(redisKey, "blacklisted", expiration, TimeUnit.SECONDS);
                    log.debug("Token已加入黑名单:剩余有效期={}秒", expiration);
                } catch (Exception e) {
                    // Redis不可用时降级到内存存储
                    log.warn("Redis不可用，降级到内存存储Token黑名单: {}", e.getMessage());
                    TOKEN_BLACKLIST.put(token, System.currentTimeMillis() + expiration * 1000);
                }
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
     * 检查Token是否在黑名单中
     * 优先检查Redis，降级检查内存存储
     */
    public boolean isTokenBlacklisted(String token) {
        // 优先检查Redis
        try {
            String redisKey = TOKEN_BLACKLIST_KEY_PREFIX + token;
            Boolean exists = redisTemplate.hasKey(redisKey);
            if (Boolean.TRUE.equals(exists)) {
                return true;
            }
        } catch (Exception e) {
            log.debug("Redis检查Token黑名单失败，降级到内存检查: {}", e.getMessage());
        }

        // 降级检查内存存储
        Long expiryTime = TOKEN_BLACKLIST.get(token);
        if (expiryTime == null) {
            return false;
        }
        // 清理过期的黑名单记录
        if (System.currentTimeMillis() > expiryTime) {
            TOKEN_BLACKLIST.remove(token);
            return false;
        }
        return true;
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

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void changePassword(Long userId, String oldPassword, String newPassword) {
        // 1. 获取用户
        User user = userMapper.selectById(userId);
        if (user == null) {
            throw new BusinessException(ErrorCode.USER_NOT_FOUND, "用户不存在");
        }

        // 2. 验证原密码
        boolean passwordMatch = BCrypt.verifyer().verify(oldPassword.toCharArray(), user.getPassword()).verified;
        if (!passwordMatch) {
            throw new BusinessException(ErrorCode.INVALID_CREDENTIALS, "原密码错误");
        }

        // 3. 新密码不能与原密码相同
        boolean samePassword = BCrypt.verifyer().verify(newPassword.toCharArray(), user.getPassword()).verified;
        if (samePassword) {
            throw new BusinessException(ErrorCode.INVALID_PARAM, "新密码不能与原密码相同");
        }

        // 4. 加密新密码并更新
        String hashedPassword = BCrypt.withDefaults().hashToString(12, newPassword.toCharArray());
        user.setPassword(hashedPassword);
        user.setUpdateTime(LocalDateTime.now());
        userMapper.updateById(user);

        log.info("用户修改密码成功: userId={}", userId);
    }
}
