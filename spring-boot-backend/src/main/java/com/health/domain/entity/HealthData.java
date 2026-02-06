package com.health.domain.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 健康数据实体
 */
@Data
@TableName("health_data")
public class HealthData {

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
     * 所属家庭ID
     */
    private Long familyId;

    /**
     * 成员ID
     */
    private Long memberId;

    /**
     * 数据类型：blood_pressure-血压，heart_rate-心率，blood_sugar-血糖，
     *          temperature-体温，weight-体重，height-身高，steps-步数，sleep-睡眠
     */
    private String dataType;

    /**
     * 数据值1（收缩压/心率/血糖值/体温/体重/身高/步数）
     */
    private BigDecimal value1;

    /**
     * 数据值2（舒张压-仅血压使用）
     */
    private BigDecimal value2;

    /**
     * 数据值3（睡眠时长-小时）
     */
    private BigDecimal value3;

    /**
     * 单位
     */
    private String unit;

    /**
     * 测量时间
     */
    private LocalDateTime measureTime;

    /**
     * 数据来源：manual-手动录入，device-设备同步
     */
    private String dataSource;

    /**
     * 设备名称
     */
    private String deviceName;

    /**
     * 备注
     */
    private String notes;

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
