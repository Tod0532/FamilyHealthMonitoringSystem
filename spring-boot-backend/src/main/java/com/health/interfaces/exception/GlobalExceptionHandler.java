package com.health.interfaces.exception;

import com.health.interfaces.response.ApiResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.validation.BindException;
import org.springframework.validation.FieldError;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingRequestHeaderException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

import javax.validation.ConstraintViolation;
import javax.validation.ConstraintViolationException;
import java.util.stream.Collectors;

/**
 * 全局异常处理器
 *
 * <p><b>重要</b>：业务代码抛出的实际是 {@link com.health.exception.BusinessException}
 * （位于 {@code com.health.exception} 包），而不是本包下的同名类。
 * 此前本处理器只注册了本包的那个类，导致真正的业务异常全部落到兜底的
 * {@code Exception} 分支，被统一转成 HTTP 500 + "系统内部错误" ——
 * 错误码与中文提示全部丢失，线上排障极其困难
 * （例如"您还未加入家庭""成员不存在"都表现为 500）。</p>
 *
 * <p>现按错误码把业务异常映射为语义正确的 HTTP 状态：
 * 401 未授权 / 403 禁止 / 404 不存在 / 400 参数错误 / 500 其它。</p>
 */
@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    // ==================== 本包内的异常（历史遗留，保留兼容） ====================

    /**
     * 业务异常（本包内的类，接口层使用）
     */
    @ExceptionHandler(BusinessException.class)
    @ResponseStatus(HttpStatus.OK)
    public ApiResponse<?> handleBusinessException(BusinessException e) {
        log.warn("业务异常: code={}, message={}", e.getCode(), e.getMessage());
        return ApiResponse.fail(e.getCode(), e.getMessage());
    }

    // ==================== 实际业务异常（com.health.exception） ====================

    /**
     * 业务异常 —— 服务层实际抛出的类型。
     *
     * <p>返回与错误码匹配的 HTTP 状态，同时保留原始业务码与中文 message，
     * 使客户端既能按 HTTP 状态做通用处理，也能按业务码精确判断。</p>
     */
    @ExceptionHandler(com.health.exception.BusinessException.class)
    public ResponseEntity<ApiResponse<?>> handleServiceBusinessException(
            com.health.exception.BusinessException e) {
        int code = e.getCode();
        HttpStatus status = mapToHttpStatus(code);
        if (status.is5xxServerError()) {
            log.error("业务异常(按系统错误处理): code={}, message={}", code, e.getMessage(), e);
        } else {
            log.warn("业务异常: code={}, http={}, message={}", code, status.value(), e.getMessage());
        }
        return ResponseEntity.status(status)
                .body(ApiResponse.fail(code, e.getMessage()));
    }

    /**
     * 业务错误码 -> HTTP 状态码。
     *
     * <p>错误码分段约定见 {@link com.health.exception.ErrorCode}：
     * 400/401/403/404/500 为通用段；1001-1006 用户；2001-2003 验证码；
     * 3001-3003 业务；4001-4006 家庭。</p>
     */
    private static HttpStatus mapToHttpStatus(int code) {
        switch (code) {
            case 400: return HttpStatus.BAD_REQUEST;
            case 401: return HttpStatus.UNAUTHORIZED;
            case 403: return HttpStatus.FORBIDDEN;
            case 404: return HttpStatus.NOT_FOUND;

            // 用户段
            case 1001: return HttpStatus.NOT_FOUND;         // 用户不存在
            case 1002: return HttpStatus.CONFLICT;          // 用户已存在
            case 1003: return HttpStatus.UNAUTHORIZED;      // 用户名或密码错误
            case 1004: return HttpStatus.FORBIDDEN;         // 账号禁用
            case 1005: return HttpStatus.UNAUTHORIZED;      // 令牌无效
            case 1006: return HttpStatus.UNAUTHORIZED;      // 令牌过期

            // 验证码段
            case 2001:
            case 2002:
            case 2003: return HttpStatus.BAD_REQUEST;

            // 业务段
            case 3001:                                      // 成员不存在
            case 3002:                                      // 数据不存在
            case 3003: return HttpStatus.NOT_FOUND;         // 规则不存在

            // 家庭段
            case 4001: return HttpStatus.NOT_FOUND;         // 家庭不存在
            case 4002: return HttpStatus.BAD_REQUEST;       // 邀请码无效
            case 4003: return HttpStatus.CONFLICT;          // 已加入家庭
            case 4004: return HttpStatus.FORBIDDEN;         // 非家庭管理员
            case 4005: return HttpStatus.FORBIDDEN;         // 不能移除管理员
            case 4006: return HttpStatus.CONFLICT;          // 家庭名称已存在

            default: return HttpStatus.BAD_REQUEST;
        }
    }

    // ==================== 参数 / 请求异常 ====================

    /**
     * 参数校验异常（RequestBody）
     */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ApiResponse<?> handleMethodArgumentNotValidException(MethodArgumentNotValidException e) {
        String message = e.getBindingResult().getFieldErrors().stream()
                .map(FieldError::getDefaultMessage)
                .collect(Collectors.joining(", "));
        log.warn("参数校验异常: {}", message);
        return ApiResponse.paramError("参数校验失败: " + message);
    }

    /**
     * 参数绑定异常
     */
    @ExceptionHandler(BindException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ApiResponse<?> handleBindException(BindException e) {
        String message = e.getBindingResult().getFieldErrors().stream()
                .map(FieldError::getDefaultMessage)
                .collect(Collectors.joining(", "));
        log.warn("参数绑定异常: {}", message);
        return ApiResponse.paramError("参数绑定失败: " + message);
    }

    /**
     * 参数校验异常（RequestParam/@PathVariable）
     */
    @ExceptionHandler(ConstraintViolationException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ApiResponse<?> handleConstraintViolationException(ConstraintViolationException e) {
        String message = e.getConstraintViolations().stream()
                .map(ConstraintViolation::getMessage)
                .collect(Collectors.joining(", "));
        log.warn("参数校验异常: {}", message);
        return ApiResponse.paramError("参数校验失败: " + message);
    }

    /**
     * 缺少必需的请求头 —— 此前会落到兜底分支变成 500。
     */
    @ExceptionHandler(MissingRequestHeaderException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ApiResponse<?> handleMissingRequestHeader(MissingRequestHeaderException e) {
        log.warn("缺少请求头: {}", e.getHeaderName());
        return ApiResponse.paramError("缺少必需的请求头: " + e.getHeaderName());
    }

    /**
     * 缺少必需的请求参数
     */
    @ExceptionHandler(MissingServletRequestParameterException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ApiResponse<?> handleMissingParam(MissingServletRequestParameterException e) {
        log.warn("缺少请求参数: {}", e.getParameterName());
        return ApiResponse.paramError("缺少必需的参数: " + e.getParameterName());
    }

    /**
     * 参数类型不匹配（如把非数字传给 Long 类型的 id）
     */
    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ApiResponse<?> handleTypeMismatch(MethodArgumentTypeMismatchException e) {
        log.warn("参数类型错误: name={}, value={}", e.getName(), e.getValue());
        return ApiResponse.paramError("参数类型错误: " + e.getName());
    }

    /**
     * 请求方法不支持 —— 此前会落到兜底分支变成 500。
     */
    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    @ResponseStatus(HttpStatus.METHOD_NOT_ALLOWED)
    public ApiResponse<?> handleMethodNotSupported(HttpRequestMethodNotSupportedException e) {
        log.warn("请求方法不支持: {}", e.getMessage());
        return ApiResponse.fail(405, "请求方法不支持: " + e.getMethod());
    }

    /**
     * JSON 体格式错误
     */
    @ExceptionHandler(org.springframework.http.converter.HttpMessageNotReadableException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ApiResponse<?> handleNotReadable(
            org.springframework.http.converter.HttpMessageNotReadableException e) {
        log.warn("请求体解析失败: {}", e.getMessage());
        return ApiResponse.paramError("请求体格式错误，请检查 JSON 是否合法");
    }

    // ==================== 安全异常 ====================

    /**
     * 认证异常
     */
    @ExceptionHandler(BadCredentialsException.class)
    @ResponseStatus(HttpStatus.UNAUTHORIZED)
    public ApiResponse<?> handleBadCredentialsException(BadCredentialsException e) {
        log.warn("认证异常: {}", e.getMessage());
        return ApiResponse.unauthorized("用户名或密码错误");
    }

    /**
     * 访问拒绝异常
     */
    @ExceptionHandler(AccessDeniedException.class)
    @ResponseStatus(HttpStatus.FORBIDDEN)
    public ApiResponse<?> handleAccessDeniedException(AccessDeniedException e) {
        log.warn("访问拒绝: {}", e.getMessage());
        return ApiResponse.forbidden("没有权限访问该资源");
    }

    /**
     * 资源不存在异常（本包内的类）
     */
    @ExceptionHandler(NotFoundException.class)
    @ResponseStatus(HttpStatus.NOT_FOUND)
    public ApiResponse<?> handleNotFoundException(NotFoundException e) {
        log.warn("资源不存在: {}", e.getMessage());
        return ApiResponse.notFound(e.getMessage());
    }

    // ==================== 兜底 ====================

    /**
     * 系统异常
     *
     * <p>能走到这里的才是真正未预期的错误（数据库语法错误、NPE 等），
     * 因此都以 ERROR 级别记录完整堆栈。</p>
     */
    @ExceptionHandler(Exception.class)
    @ResponseStatus(HttpStatus.INTERNAL_SERVER_ERROR)
    public ApiResponse<?> handleException(Exception e) {
        log.error("系统内部错误: {}", e.toString(), e);
        return ApiResponse.fail("系统内部错误，请稍后重试");
    }
}
