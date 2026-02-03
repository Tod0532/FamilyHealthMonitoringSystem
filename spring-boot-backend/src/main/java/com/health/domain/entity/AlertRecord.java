package com.health.domain.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.time.LocalDateTime;

/**
 * 预警记录实体
 */
@Data
@TableName("alert_record")
public class AlertRecord {

    /**
     * 主键ID
     */
    @TableId(type = IdType.ASSIGN_ID)
    private Long id;

    /**
     * 用户ID
     */
    private Long userId;

    /**
     * 成员ID
     */
    private Long memberId;

    /**
     * 预警规则ID
     */
    private Long ruleId;

    /**
     * 预警类型
     */
    private String alertType;

    /**
     * 预警级别
     */
    private String alertLevel;

    /**
     * 预警标题
     */
    private String title;

    /**
     * 预警内容
     */
    private String content;

    /**
     * 触发数值
     */
    private String triggerValue;

    /**
     * 状态：unread-未读，read-已读，handled-已处理
     */
    private String status;

    /**
     * 处理时间
     */
    private LocalDateTime handleTime;

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
