package com.health.interfaces.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 用户视图对象
 */
@Data
@Builder
@Schema(description = "用户视图对象")
public class UserVO {

    @Schema(description = "用户ID")
    private Long id;

    @Schema(description = "手机号")
    private String phone;

    @Schema(description = "昵称")
    private String nickname;

    @Schema(description = "头像")
    private String avatar;

    @Schema(description = "性别：0-未知，1-男，2-女")
    private Integer gender;

    @Schema(description = "出生日期")
    private LocalDateTime birthday;

    @Schema(description = "账号状态：0-正常，1-禁用")
    private Integer status;

    @Schema(description = "最后登录时间")
    private LocalDateTime lastLoginTime;

    @Schema(description = "创建时间")
    private LocalDateTime createTime;
}
