package com.health.interfaces.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;
import java.time.LocalDateTime;

/**
 * 家庭成员响应
 */
@Data
@Schema(description = "家庭成员响应")
public class FamilyMemberResponse {

    @Schema(description = "成员ID")
    private Long id;

    @Schema(description = "成员名称")
    private String name;

    @Schema(description = "性别：0-未知，1-男，2-女")
    private Integer gender;

    @Schema(description = "关系")
    private String relation;

    @Schema(description = "角色")
    private String role;

    @Schema(description = "出生日期")
    private String birthday;

    @Schema(description = "头像URL")
    private String avatar;

    @Schema(description = "备注")
    private String notes;

    @Schema(description = "创建时间")
    private LocalDateTime createTime;
}
