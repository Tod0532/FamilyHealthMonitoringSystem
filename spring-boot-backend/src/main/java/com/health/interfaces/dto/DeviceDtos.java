package com.health.interfaces.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import javax.validation.constraints.NotBlank;
import javax.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;

/**
 * 设备相关的请求/响应对象
 *
 * 集中放在一个文件里（静态内部类），避免为每个小对象单开文件。
 */
public class DeviceDtos {

    /** App 生成绑定码：绑定到哪个成员 */
    @Data
    public static class BindCodeRequest {
        @NotNull(message = "成员ID不能为空")
        private Long memberId;
        @Schema(description = "设备名，便于用户在 App 里分辨", example = "卧室手环桥")
        private String deviceName;
    }

    /** App 拿到的绑定码（含过期时间） */
    @Data
    public static class BindCodeResponse {
        private String bindCode;
        @Schema(description = "有效期（分钟）")
        private Integer expireMinutes;
        private Long memberId;
        private String memberName;
    }

    /** 设备端用绑定码换取令牌 */
    @Data
    public static class BindRequest {
        @NotBlank(message = "绑定码不能为空")
        private String bindCode;
        @NotBlank(message = "设备序列号不能为空")
        private String deviceSn;
        private String deviceName;
        private String deviceType;
        private String firmwareVersion;
    }

    /** 绑定成功返回给设备：**只返回一次**，设备需存入 NVS */
    @Data
    public static class BindResponse {
        private String deviceToken;
        private Long memberId;
        private String memberName;
        private String serverTime;
    }

    /** 设备上报健康数据 */
    @Data
    public static class DeviceReportRequest {
        @NotBlank(message = "数据类型不能为空")
        private String dataType;
        @NotNull(message = "数值不能为空")
        private BigDecimal value1;
        private BigDecimal value2;
        private BigDecimal value3;
        private String unit;
        /** 可空；为空则用服务端时间 */
        private String measureTime;
    }

    /** App 侧看到的设备信息 */
    @Data
    public static class DeviceVO {
        private Long id;
        private String deviceSn;
        private String deviceName;
        private String deviceType;
        private Long memberId;
        private String memberName;
        private String lastSeen;
        /** 在线：最近 5 分钟内有心跳或上报 */
        private Boolean online;
        private String firmwareVersion;
        private String createTime;
    }
}
