package com.health.domain.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.time.LocalDateTime;

/**
 * 用户实体
 */
@Data
@TableName("user")
public class User {

    /**
     * 主键ID（雪花算法生成）
     */
    @TableId(type = IdType.ASSIGN_ID)
    private Long id;

    /**
     * 手机号（唯一，登录账号）
     */
    private String phone;

    /**
     * 密码（BCrypt加密）
     */
    private String password;

    /**
     * 昵称
     */
    private String nickname;

    /**
     * 头像URL
     */
    private String avatar;

    /**
     * 性别：0-未知，1-男，2-女
     */
    private Integer gender;

    /**
     * 出生日期
     */
    private LocalDateTime birthday;

    /**
     * 账号状态：0-正常，1-禁用
     */
    private Integer status;

    /**
     * 最后登录时间
     */
    private LocalDateTime lastLoginTime;

    /**
     * 最后登录IP
     */
    private String lastLoginIp;

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
