package com.health.interfaces.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 健康数据响应
 */
@Data
@Schema(description = "健康数据响应")
public class HealthDataResponse {

    @Schema(description = "数据ID")
    private Long id;

    @Schema(description = "成员ID")
    private Long memberId;

    @Schema(description = "成员名称")
    private String memberName;

    @Schema(description = "数据类型")
    private String dataType;

    @Schema(description = "数据类型标签")
    private String dataTypeLabel;

    @Schema(description = "数据值1")
    private BigDecimal value1;

    @Schema(description = "数据值2")
    private BigDecimal value2;

    @Schema(description = "数据值3")
    private BigDecimal value3;

    @Schema(description = "单位")
    private String unit;

    @Schema(description = "显示值（格式化后的值）")
    private String displayValue;

    @Schema(description = "测量时间")
    private LocalDateTime measureTime;

    @Schema(description = "数据来源")
    private String dataSource;

    @Schema(description = "设备名称")
    private String deviceName;

    @Schema(description = "备注")
    private String notes;

    @Schema(description = "创建时间")
    private LocalDateTime createTime;
}
