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

    @Schema(description = "性别：male-男，female-女")
    private String gender;

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
