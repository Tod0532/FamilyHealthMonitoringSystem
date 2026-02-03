package com.health.interfaces.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;

/**
 * 数据统计响应
 */
@Data
@Schema(description = "数据统计响应")
public class HealthStatsResponse {

    @Schema(description = "总记录数")
    private Long totalRecords;

    @Schema(description = "平均值")
    private Double average;

    @Schema(description = "最大值")
    private Double maximum;

    @Schema(description = "最小值")
    private Double minimum;

    @Schema(description = "最早记录时间")
    private String earliestTime;

    @Schema(description = "最近记录时间")
    private String latestTime;

    @Schema(description = "最近7天趋势数据")
    private java.util.List<TrendData> trendData;

    @Data
    @Schema(description = "趋势数据")
    public static class TrendData {
        @Schema(description = "日期")
        private String date;

        @Schema(description = "值")
        private Double value;
    }
}
