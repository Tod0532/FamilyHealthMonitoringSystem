package com.health.interfaces.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 预警记录响应
 */
@Data
@Schema(description = "预警记录响应")
public class AlertRecordResponse {

    @Schema(description = "记录ID")
    private Long id;

    @Schema(description = "成员ID")
    private Long memberId;

    @Schema(description = "成员名称")
    private String memberName;

    @Schema(description = "预警类型")
    private String alertType;

    @Schema(description = "预警类型标签")
    private String alertTypeLabel;

    @Schema(description = "预警级别")
    private String alertLevel;

    @Schema(description = "预警级别标签")
    private String alertLevelLabel;

    @Schema(description = "预警标题")
    private String title;

    @Schema(description = "预警内容")
    private String content;

    @Schema(description = "触发数值")
    private String triggerValue;

    @Schema(description = "状态")
    private String status;

    @Schema(description = "状态标签")
    private String statusLabel;

    @Schema(description = "处理时间")
    private LocalDateTime handleTime;

    @Schema(description = "创建时间")
    private LocalDateTime createTime;
}
