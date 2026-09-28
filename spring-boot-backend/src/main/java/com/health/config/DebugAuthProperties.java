package com.health.config;

import lombok.Data;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

/**
 * 调试用认证配置
 *
 * <p><b>背景</b>：{@link com.health.filter.JwtAuthenticationFilter} 原先存在一个
 * 无条件的「开发环境降级」分支 —— 当请求未携带有效 JWT 时，直接信任客户端传来的
 * {@code X-User-Id} 请求头并据此建立认证。该分支没有任何环境判断，因此在生产环境
 * 同样生效，导致任何人只需构造一个 {@code X-User-Id} 头即可冒充任意用户、
 * 读写全部健康数据。</p>
 *
 * <p><b>修复策略</b>：把这个能力变成显式、受限、默认关闭的调试开关：</p>
 * <ul>
 *   <li>{@link Profile @Profile("dev")} —— 该 Bean 只在 dev profile 下存在，
 *       生产环境（prod）下连 Bean 都不会创建，开关无从打开。</li>
 *   <li>{@link ConditionalOnProperty} —— 即使处于 dev，也还需显式设置
 *       {@code app.debug.trust-user-id-header=true} 才生效，默认关闭。</li>
 * </ul>
 *
 * <p><b>为什么不再需要它</b>：调试时应当正常登录获取 JWT（登录接口本身是
 * permitAll 的）。若确实需要无 JWT 联调，在 dev 环境显式打开此开关即可。</p>
 */
@Data
@Component
@Profile("dev")
@ConditionalOnProperty(
        prefix = "app.debug",
        name = "trust-user-id-header",
        havingValue = "true"
)
@ConfigurationProperties(prefix = "app.debug")
public class DebugAuthProperties {

    /**
     * 是否信任客户端传入的 X-User-Id 请求头（无 JWT 时）。
     *
     * <p>仅用于本地开发/联调。生产环境该 Bean 不存在，此值恒为 false。</p>
     */
    private boolean trustUserIdHeader = false;
}
