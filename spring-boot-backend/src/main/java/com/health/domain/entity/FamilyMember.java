package com.health.domain.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * 家庭成员实体
 */
@Data
@TableName("family_member")
public class FamilyMember {

    /**
     * 主键ID
     */
    @TableId(type = IdType.ASSIGN_ID)
    private Long id;

    /**
     * 用户ID（所属家庭）
     */
    private Long userId;

    /**
     * 所属家庭ID
     */
    private Long familyId;

    /**
     * 成员名称
     */
    private String name;

    /**
     * 性别：male-男，female-女
     */
    private String gender;

    /**
     * 关系：father-父亲，mother-母亲，spouse-配偶，child-子女，other-其他
     */
    private String relation;

    /**
     * 角色：admin-管理员，member-普通成员，guest-访客
     */
    private String role;

    /**
     * 出生日期
     */
    private LocalDate birthday;

    /**
     * 头像URL
     */
    private String avatar;

    /**
     * 备注
     */
    private String notes;

    /**
     * 排序序号
     */
    private Integer sortOrder;

    /**
     * 创建时间
     */
    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createTime;

    /**
     * 更新时间
     */
    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updateTime;

    /**
     * 逻辑删除：0-未删除，1-已删除
     */
    @TableLogic
    private Integer deleted;
}
