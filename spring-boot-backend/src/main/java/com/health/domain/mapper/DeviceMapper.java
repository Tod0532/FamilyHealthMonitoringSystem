package com.health.domain.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.health.domain.entity.Device;
import org.apache.ibatis.annotations.Mapper;

/**
 * 设备 Mapper
 */
@Mapper
public interface DeviceMapper extends BaseMapper<Device> {
}
