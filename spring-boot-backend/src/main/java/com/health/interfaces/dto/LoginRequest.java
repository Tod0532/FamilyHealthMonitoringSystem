package com.health.interfaces.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

/**
 * 登录请求
 */
@Data
@Schema(description = "登录请求")
public class LoginRequest {

    @NotBlank(message = "手机号不能为空")
    @Schema(description = "手机号", example = "13800138000")
    private String phone;

    @NotBlank(message = "密码不能为空")
    @Schema(description = "密码", example = "123456")
    private String password;
}
