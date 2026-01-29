package com.health.interfaces.exception;

/**
 * 资源不存在异常
 *
 * @author 开发团队
 * @since 1.0.0
 */
public class NotFoundException extends BusinessException {

    private static final long serialVersionUID = 1L;

    public NotFoundException(String message) {
        super(3001, message);
    }

    public NotFoundException(String resource, Object id) {
        super(String.format("%s不存在: %s", resource, id));
    }
}
