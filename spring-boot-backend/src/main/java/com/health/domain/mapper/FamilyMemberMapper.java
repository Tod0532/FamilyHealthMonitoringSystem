package com.health.domain.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.health.domain.entity.FamilyMember;
import org.apache.ibatis.annotations.Mapper;

/**
 * 家庭成员Mapper
 */
@Mapper
public interface FamilyMemberMapper extends BaseMapper<FamilyMember> {
}
