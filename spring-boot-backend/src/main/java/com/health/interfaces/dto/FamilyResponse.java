package com.health.interfaces.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 家庭响应DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Schema(description = "家庭信息响应")
public class FamilyResponse {

    /**
     * 家庭ID
     */
    @Schema(description = "家庭ID")
    private Long id;

    /**
     * 家庭名称
     */
    @Schema(description = "家庭名称")
    private String familyName;

    /**
     * 家庭邀请码
     */
    @Schema(description = "家庭邀请码")
    private String familyCode;

    /**
     * 管理员用户ID
     */
    @Schema(description = "管理员用户ID")
    private Long adminId;

    /**
     * 管理员昵称
     */
    @Schema(description = "管理员昵称")
    private String adminNickname;

    /**
     * 成员数量
     */
    @Schema(description = "成员数量")
    private Integer memberCount;

    /**
     * 创建时间
     */
    @Schema(description = "创建时间")
    private LocalDateTime createTime;

    /**
     * 当前用户在家庭中的角色
     */
    @Schema(description = "当前用户在家庭中的角色")
    private String myRole;
}
