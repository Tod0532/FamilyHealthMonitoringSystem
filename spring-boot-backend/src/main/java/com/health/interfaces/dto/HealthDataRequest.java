package com.health.interfaces.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import javax.validation.constraints.NotBlank;
import javax.validation.constraints.NotNull;
import lombok.Data;
import java.math.BigDecimal;

/**
 * 健康数据请求
 */
@Data
@Schema(description = "健康数据请求")
public class HealthDataRequest {

    @Schema(description = "成员ID", required = true)
    @NotNull(message = "成员ID不能为空")
    private Long memberId;

    @Schema(description = "数据类型：blood_pressure-血压，heart_rate-心率，blood_sugar-血糖，temperature-体温，weight-体重，height-身高，steps-步数，sleep-睡眠", required = true)
    @NotBlank(message = "数据类型不能为空")
    private String dataType;

    @Schema(description = "数据值1（收缩压/心率/血糖值/体温/体重/身高/步数）")
    private BigDecimal value1;

    @Schema(description = "数据值2（舒张压-仅血压使用）")
    private BigDecimal value2;

    @Schema(description = "数据值3（睡眠时长-小时）")
    private BigDecimal value3;

    @Schema(description = "单位")
    private String unit;

    @Schema(description = "测量时间，格式：yyyy-MM-dd HH:mm:ss")
    private String measureTime;

    @Schema(description = "数据来源：manual-手动录入，device-设备同步")
    private String dataSource;

    @Schema(description = "设备名称")
    private String deviceName;

    @Schema(description = "备注")
    private String notes;
}
