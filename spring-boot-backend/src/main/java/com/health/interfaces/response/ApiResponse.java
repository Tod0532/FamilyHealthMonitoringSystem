package com.health.interfaces.response;

import com.fasterxml.jackson.annotation.JsonInclude;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serializable;
import java.time.Instant;

/**
 * 统一API响应格式
 *
 * @param <T> 数据类型
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
@Schema(description = "统一响应格式")
public class ApiResponse<T> implements Serializable {

    private static final long serialVersionUID = 1L;

    /**
     * 状态码
     */
    @Schema(description = "状态码", example = "200")
    private Integer code;

    /**
     * 提示信息
     */
    @Schema(description = "提示信息", example = "success")
    private String message;

    /**
     * 业务数据
     */
    @Schema(description = "业务数据")
    private T data;

    /**
     * 时间戳
     */
    @Schema(description = "时间戳", example = "1706496000000")
    private Long timestamp;

    /**
     * 请求追踪ID
     */
    @Schema(description = "请求追踪ID")
    private String requestId;

    /**
     * 成功响应
     */
    public static <T> ApiResponse<T> success() {
        return ApiResponse.<T>builder()
                .code(200)
                .message("success")
                .timestamp(Instant.now().toEpochMilli())
                .build();
    }

    /**
     * 成功响应（带数据）
     */
    public static <T> ApiResponse<T> success(T data) {
        return ApiResponse.<T>builder()
                .code(200)
                .message("success")
                .data(data)
                .timestamp(Instant.now().toEpochMilli())
                .build();
    }

    /**
     * 成功响应（带消息和数据）
     */
    public static <T> ApiResponse<T> success(String message, T data) {
        return ApiResponse.<T>builder()
                .code(200)
                .message(message)
                .data(data)
                .timestamp(Instant.now().toEpochMilli())
                .build();
    }

    /**
     * 失败响应
     */
    public static <T> ApiResponse<T> fail(Integer code, String message) {
        return ApiResponse.<T>builder()
                .code(code)
                .message(message)
                .timestamp(Instant.now().toEpochMilli())
                .build();
    }

    /**
     * 失败响应（默认错误码）
     */
    public static <T> ApiResponse<T> fail(String message) {
        return fail(5000, message);
    }

    /**
     * 业务异常响应
     */
    public static <T> ApiResponse<T> businessError(String message) {
        return fail(2001, message);
    }

    /**
     * 参数错误响应
     */
    public static <T> ApiResponse<T> paramError(String message) {
        return fail(1001, message);
    }

    /**
     * 未授权响应
     */
    public static <T> ApiResponse<T> unauthorized(String message) {
        return fail(2001, message);
    }

    /**
     * 禁止访问响应
     */
    public static <T> ApiResponse<T> forbidden(String message) {
        return fail(2003, message);
    }

    /**
     * 资源不存在响应
     */
    public static <T> ApiResponse<T> notFound(String message) {
        return fail(3001, message);
    }
}
