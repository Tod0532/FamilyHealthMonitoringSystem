package com.health.service;

import com.health.interfaces.dto.FamilyMemberRequest;
import com.health.interfaces.dto.FamilyMemberResponse;

import java.util.List;

/**
 * 家庭成员服务接口
 */
public interface FamilyMemberService {

    /**
     * 获取用户的所有家庭成员
     */
    List<FamilyMemberResponse> getList(Long userId);

    /**
     * 根据ID获取成员详情
     */
    FamilyMemberResponse getById(Long id, Long userId);

    /**
     * 添加家庭成员
     */
    FamilyMemberResponse create(Long userId, FamilyMemberRequest request);

    /**
     * 更新家庭成员
     */
    FamilyMemberResponse update(Long id, Long userId, FamilyMemberRequest request);

    /**
     * 删除家庭成员
     */
    void delete(Long id, Long userId);

    /**
     * 批量删除家庭成员
     */
    void batchDelete(List<Long> ids, Long userId);
}
