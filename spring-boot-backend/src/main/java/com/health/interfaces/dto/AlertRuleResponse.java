package com.health.interfaces.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 预警规则响应
 */
@Data
@Schema(description = "预警规则响应")
public class AlertRuleResponse {

    @Schema(description = "规则ID")
    private Long id;

    @Schema(description = "预警类型")
    private String alertType;

    @Schema(description = "预警类型标签")
    private String alertTypeLabel;

    @Schema(description = "预警级别")
    private String alertLevel;

    @Schema(description = "预警级别标签")
    private String alertLevelLabel;

    @Schema(description = "条件类型")
    private String conditionType;

    @Schema(description = "条件描述")
    private String conditionDesc;

    @Schema(description = "阈值1")
    private Double threshold1;

    @Schema(description = "阈值2")
    private Double threshold2;

    @Schema(description = "规则名称")
    private String ruleName;

    @Schema(description = "是否启用")
    private Integer enabled;

    @Schema(description = "是否系统默认")
    private Integer isDefault;

    @Schema(description = "创建时间")
    private LocalDateTime createTime;
}
