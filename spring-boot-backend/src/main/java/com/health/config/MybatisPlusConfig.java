package com.health.config;

import com.baomidou.mybatisplus.core.handlers.MetaObjectHandler;
import org.apache.ibatis.reflection.MetaObject;
import org.mybatis.spring.annotation.MapperScan;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.time.LocalDateTime;

/**
 * MyBatis-Plus 配置
 *
 * 重要：实体类上的 {@code @TableField(fill = FieldFill.INSERT / INSERT_UPDATE)}
 * 只是「声明」，真正执行填充的是 {@link MetaObjectHandler}。
 *
 * 此前本项目里没有任何 MetaObjectHandler 实现，导致：
 *   - createTime / updateTime 被显式以 NULL 写入 INSERT 语句
 *   - 该显式 NULL 又会覆盖数据库列的 DEFAULT CURRENT_TIMESTAMP
 *   - 于是所有通过接口新建的记录（健康数据、家庭、成员、预警规则/记录等）
 *     时间戳全部为空
 * 实测：App 新建一条健康数据后 createTime 为 null，而 SQL 种子数据有值。
 * 这会让按时间排序、统计、导出、图表等全部失真。
 */
@Configuration
@MapperScan("com.health.domain.mapper")
public class MybatisPlusConfig {

    /**
     * 公共字段自动填充：新增时写入 createTime / updateTime，更新时刷新 updateTime。
     */
    @Bean
    public MetaObjectHandler metaObjectHandler() {
        return new MetaObjectHandler() {
            @Override
            public void insertFill(MetaObject metaObject) {
                LocalDateTime now = LocalDateTime.now();
                strictInsertFill(metaObject, "createTime", LocalDateTime.class, now);
                strictInsertFill(metaObject, "updateTime", LocalDateTime.class, now);
            }

            @Override
            public void updateFill(MetaObject metaObject) {
                strictUpdateFill(metaObject, "updateTime", LocalDateTime.class, LocalDateTime.now());
            }
        };
    }
}
