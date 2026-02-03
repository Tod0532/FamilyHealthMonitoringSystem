package com.health.domain.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.health.domain.entity.HealthData;
import org.apache.ibatis.annotations.Mapper;

/**
 * 健康数据Mapper
 */
@Mapper
public interface HealthDataMapper extends BaseMapper<HealthData> {
}
