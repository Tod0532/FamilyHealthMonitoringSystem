package com.health.config;

import java.lang.annotation.*;

/**
 * 角色权限验证注解
 * 用于标记需要特定角色才能访问的API方法
 *
 * 支持的角色：
 * - ADMIN: 管理员，拥有所有权限
 * - USER: 普通用户，只能操作自己的数据
 * - GUEST: 访客，只有只读权限
 */
@Target({ElementType.METHOD, ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
@Documented
public @interface RequireRole {
    /**
     * 允许访问的角色列表
     * 支持多个角色，用户拥有任一角色即可访问
     */
    String[] value();
}
