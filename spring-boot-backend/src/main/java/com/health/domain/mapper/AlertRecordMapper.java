package com.health.domain.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.health.domain.entity.AlertRecord;
import org.apache.ibatis.annotations.Mapper;

/**
 * 预警记录Mapper
 */
@Mapper
public interface AlertRecordMapper extends BaseMapper<AlertRecord> {
}
