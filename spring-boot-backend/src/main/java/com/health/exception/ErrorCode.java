package com.health.exception;

import lombok.Getter;

/**
 * 错误码枚举
 */
@Getter
public enum ErrorCode {

    // 通用错误码
    SUCCESS(200, "操作成功"),
    INVALID_PARAM(400, "参数错误"),
    UNAUTHORIZED(401, "未授权"),
    FORBIDDEN(403, "禁止访问"),
    NOT_FOUND(404, "资源不存在"),
    INTERNAL_ERROR(500, "系统内部错误"),

    // 用户相关错误码
    USER_NOT_FOUND(1001, "用户不存在"),
    USER_ALREADY_EXISTS(1002, "用户已存在"),
    INVALID_CREDENTIALS(1003, "用户名或密码错误"),
    ACCOUNT_DISABLED(1004, "账号已被禁用"),
    INVALID_TOKEN(1005, "令牌无效或已过期"),
    TOKEN_EXPIRED(1006, "令牌已过期"),

    // 验证码相关
    INVALID_SMS_CODE(2001, "验证码错误"),
    SMS_CODE_EXPIRED(2002, "验证码已过期"),
    SMS_SEND_FAILED(2003, "验证码发送失败"),

    // 业务相关
    MEMBER_NOT_FOUND(3001, "成员不存在"),
    DATA_NOT_FOUND(3002, "数据不存在"),
    RULE_NOT_FOUND(3003, "规则不存在");

    private final int code;
    private final String message;

    ErrorCode(int code, String message) {
        this.code = code;
        this.message = message;
    }
}
