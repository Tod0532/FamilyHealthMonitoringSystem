package com.health.domain.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.time.LocalDateTime;

/**
 * 预警规则实体
 */
@Data
@TableName("alert_rule")
public class AlertRule {

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
     * 预警类型：blood_pressure-血压，heart_rate-心率，blood_sugar-血糖，temperature-体温，weight-体重
     */
    private String alertType;

    /**
     * 预警级别：info-信息，warning-警告，danger-危险
     */
    private String alertLevel;

    /**
     * 条件类型：gt-大于，lt-小于，eq-等于，between-区间
     */
    private String conditionType;

    /**
     * 阈值1（最小值/下限）
     */
    private Double threshold1;

    /**
     * 阈值2（最大值/上限）
     */
    private Double threshold2;

    /**
     * 规则名称
     */
    private String ruleName;

    /**
     * 是否启用：0-禁用，1-启用
     */
    private Integer enabled;

    /**
     * 是否系统默认：0-自定义，1-系统默认
     */
    private Integer isDefault;

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
