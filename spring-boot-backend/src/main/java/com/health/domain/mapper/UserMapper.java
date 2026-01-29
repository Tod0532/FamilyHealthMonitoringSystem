package com.health.domain.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.health.domain.entity.User;
import org.apache.ibatis.annotations.Mapper;

/**
 * 用户 Mapper
 */
@Mapper
public interface UserMapper extends BaseMapper<User> {
}
