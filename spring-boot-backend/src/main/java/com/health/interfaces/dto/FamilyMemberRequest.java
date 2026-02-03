package com.health.interfaces.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import javax.validation.constraints.NotBlank;
import javax.validation.constraints.NotNull;
import lombok.Data;

/**
 * 家庭成员添加/编辑请求
 */
@Data
@Schema(description = "家庭成员请求")
public class FamilyMemberRequest {

    @Schema(description = "成员ID（编辑时必填）")
    private Long id;

    @Schema(description = "成员名称", required = true)
    @NotBlank(message = "成员名称不能为空")
    private String name;

    @Schema(description = "性别：male-男，female-女", required = true)
    @NotBlank(message = "性别不能为空")
    private String gender;

    @Schema(description = "关系：father-父亲，mother-母亲，spouse-配偶，child-子女，other-其他", required = true)
    @NotBlank(message = "关系不能为空")
    private String relation;

    @Schema(description = "角色：admin-管理员，member-普通成员，guest-访客")
    private String role;

    @Schema(description = "出生日期")
    private String birthday;

    @Schema(description = "头像URL")
    private String avatar;

    @Schema(description = "备注")
    private String notes;
}
