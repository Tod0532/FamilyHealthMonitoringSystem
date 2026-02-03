package com.health.domain.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.health.domain.entity.AlertRule;
import org.apache.ibatis.annotations.Mapper;

/**
 * 预警规则Mapper
 */
@Mapper
public interface AlertRuleMapper extends BaseMapper<AlertRule> {
}
