package com.health.interfaces.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import javax.validation.constraints.NotBlank;
import javax.validation.constraints.NotNull;
import lombok.Data;

/**
 * 预警规则请求
 */
@Data
@Schema(description = "预警规则请求")
public class AlertRuleRequest {

    @NotBlank(message = "预警类型不能为空")
    @Schema(description = "预警类型", example = "blood_pressure", required = true)
    private String alertType;

    @NotBlank(message = "预警级别不能为空")
    @Schema(description = "预警级别", example = "warning", required = true)
    private String alertLevel;

    @NotBlank(message = "条件类型不能为空")
    @Schema(description = "条件类型", example = "gt", required = true)
    private String conditionType;

    @NotNull(message = "阈值不能为空")
    @Schema(description = "阈值1（最小值/下限）", required = true)
    private Double threshold1;

    @Schema(description = "阈值2（最大值/上限，between类型时必填）")
    private Double threshold2;

    @Schema(description = "规则名称")
    private String ruleName;

    @Schema(description = "是否启用：0-禁用，1-启用", example = "1")
    private Integer enabled;
}
