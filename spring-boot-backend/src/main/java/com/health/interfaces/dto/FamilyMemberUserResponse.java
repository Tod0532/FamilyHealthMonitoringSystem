package com.health.interfaces.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * 家庭用户响应DTO（用于成员列表）
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Schema(description = "家庭用户信息")
public class FamilyMemberUserResponse {

    /**
     * 用户ID
     */
    @Schema(description = "用户ID")
    private Long id;

    /**
     * 手机号
     */
    @Schema(description = "手机号")
    private String phone;

    /**
     * 昵称
     */
    @Schema(description = "昵称")
    private String nickname;

    /**
     * 头像
     */
    @Schema(description = "头像")
    private String avatar;

    /**
     * 性别
     */
    @Schema(description = "性别")
    private String gender;

    /**
     * 出生日期
     */
    @Schema(description = "出生日期")
    private LocalDate birthday;

    /**
     * 家庭角色：admin-管理员，member-普通成员
     */
    @Schema(description = "家庭角色")
    private String familyRole;

    /**
     * 加入时间
     */
    @Schema(description = "加入时间")
    private LocalDateTime joinTime;

    /**
     * 是否为当前用户
     */
    @Schema(description = "是否为当前用户")
    private Boolean isMe;
}
