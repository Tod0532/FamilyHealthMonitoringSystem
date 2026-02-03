package com.health.interfaces.vo;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;

/**
 * 统一响应结果
 */
@Data
@Schema(description = "统一响应结果")
public class Result<T> {

    @Schema(description = "响应码")
    private Integer code;

    @Schema(description = "响应消息")
    private String message;

    @Schema(description = "响应数据")
    private T data;

    @Schema(description = "时间戳")
    private Long timestamp;

    public Result() {
        this.timestamp = System.currentTimeMillis();
    }

    public Result(Integer code, String message, T data) {
        this.code = code;
        this.message = message;
        this.data = data;
        this.timestamp = System.currentTimeMillis();
    }

    public static <T> Result<T> success() {
        return new Result<>(200, "操作成功", null);
    }

    public static <T> Result<T> success(T data) {
        return new Result<>(200, "操作成功", data);
    }

    public static <T> Result<T> success(String message, T data) {
        return new Result<>(200, message, data);
    }

    public static <T> Result<T> error(String message) {
        return new Result<>(500, message, null);
    }

    public static <T> Result<T> error(Integer code, String message) {
        return new Result<>(code, message, null);
    }

    public static <T> Result<T> unauthorized() {
        return new Result<>(401, "未授权，请先登录", null);
    }

    public static <T> Result<T> forbidden() {
        return new Result<>(403, "无权限访问", null);
    }

    public static <T> Result<T> notFound() {
        return new Result<>(404, "资源不存在", null);
    }
}
