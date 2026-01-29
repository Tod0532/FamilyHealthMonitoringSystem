package com.health.interfaces.exception;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

/**
 * 错误码枚举
 *
 * @author 开发团队
 * @since 1.0.0
 */
@Getter
@RequiredArgsConstructor
public enum ErrorCode {

    // ========== 通用错误 (1000-1999) ==========
    PARAM_ERROR(1001, "参数错误"),
    PARAM_MISSING(1002, "缺少必填参数"),
    PARAM_FORMAT_ERROR(1003, "参数格式错误"),
    OPERATION_TOO_FREQUENT(1004, "操作过于频繁"),

    // ========== 认证授权错误 (2000-2999) ==========
    UNAUTHORIZED(2001, "未授权，请重新登录"),
    TOKEN_EXPIRED(2002, "Token已过期"),
    TOKEN_INVALID(2003, "Token无效"),
    INVALID_TOKEN(2003, "令牌无效"),
    FORBIDDEN(2005, "没有权限访问"),
    ACCOUNT_DISABLED(2006, "账号已被禁用"),
    INVALID_CREDENTIALS(2007, "账号或密码错误"),

    // ========== 业务错误 (3000-3999) ==========
    RESOURCE_NOT_FOUND(3001, "资源不存在"),
    RESOURCE_ALREADY_EXISTS(3002, "资源已存在"),
    USER_NOT_FOUND(3003, "用户不存在"),
    USER_ALREADY_EXISTS(3010, "用户已存在"),
    FAMILY_NOT_FOUND(3004, "家庭不存在"),
    MEMBER_NOT_FOUND(3005, "成员不存在"),
    HEALTH_DATA_NOT_FOUND(3006, "健康数据不存在"),
    WARNING_RULE_NOT_FOUND(3007, "预警规则不存在"),
    HEALTH_CONTENT_NOT_FOUND(3008, "健康内容不存在"),

    // 用户相关
    PHONE_ALREADY_REGISTERED(3011, "手机号已注册"),
    PHONE_NOT_REGISTERED(3012, "手机号未注册"),
    VERIFICATION_CODE_ERROR(3013, "验证码错误"),
    PASSWORD_ERROR(3014, "密码错误"),
    OLD_PASSWORD_ERROR(3015, "原密码错误"),

    // 参数相关
    INVALID_PARAM(1005, "参数无效"),

    // 家庭相关
    NOT_FAMILY_ADMIN(3020, "不是家庭管理员"),
    ALREADY_FAMILY_MEMBER(3021, "已是家庭成员"),
    NOT_FAMILY_MEMBER(3022, "不是家庭成员"),

    // 健康数据相关
    INVALID_HEALTH_DATA(3030, "无效的健康数据"),
    DUPLICATE_HEALTH_DATA(3031, "健康数据已存在"),

    // ========== 系统错误 (5000-5999) ==========
    SYSTEM_ERROR(5000, "系统内部错误"),
    DATABASE_ERROR(5001, "数据库错误"),
    NETWORK_ERROR(5002, "网络错误"),
    THIRD_PARTY_ERROR(5003, "第三方服务错误"),
    FILE_UPLOAD_ERROR(5004, "文件上传错误");

    /**
     * 错误码
     */
    private final Integer code;

    /**
     * 错误消息
     */
    private final String message;
}
