package com.health.interfaces.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import javax.validation.constraints.NotBlank;
import javax.validation.constraints.Pattern;
import lombok.Data;

/**
 * 注册请求
 */
@Data
@Schema(description = "注册请求")
public class RegisterRequest {

    @NotBlank(message = "手机号不能为空")
    @Pattern(regexp = "^1[3-9]\\d{9}$", message = "手机号格式不正确")
    @Schema(description = "手机号", example = "13800138000")
    private String phone;

    @NotBlank(message = "密码不能为空")
    @Pattern(regexp = "^(?=.*[a-zA-Z])(?=.*\\d).{6,20}$", message = "密码必须包含字母和数字，长度6-20位")
    @Schema(description = "密码（6-20位，包含字母和数字）", example = "abc123")
    private String password;

    @NotBlank(message = "确认密码不能为空")
    @Schema(description = "确认密码", example = "abc123")
    private String confirmPassword;

    @NotBlank(message = "验证码不能为空")
    @Schema(description = "短信验证码", example = "123456")
    private String smsCode;

    @Schema(description = "昵称", example = "健康达人")
    private String nickname;
}
