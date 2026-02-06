package com.health.service;

import com.health.interfaces.dto.*;

import java.util.List;

/**
 * 家庭服务接口
 */
public interface FamilyService {

    /**
     * 创建家庭
     * @param userId 用户ID
     * @param request 创建家庭请求
     * @return 家庭响应
     */
    FamilyResponse createFamily(Long userId, FamilyCreateRequest request);

    /**
     * 获取我的家庭信息
     * @param userId 用户ID
     * @return 家庭响应，未加入家庭返回null
     */
    FamilyResponse getMyFamily(Long userId);

    /**
     * 获取家庭二维码信息
     * @param userId 用户ID
     * @return 二维码响应
     */
    FamilyQrCodeResponse getQrCode(Long userId);

    /**
     * 通过邀请码解析家庭信息
     * @param inviteCode 邀请码
     * @return 家庭信息
     */
    FamilyResponse parseInviteCode(String inviteCode);

    /**
     * 加入家庭
     * @param userId 用户ID
     * @param request 加入家庭请求
     * @return 家庭响应
     */
    FamilyResponse joinFamily(Long userId, FamilyJoinRequest request);

    /**
     * 退出家庭
     * @param userId 用户ID
     */
    void leaveFamily(Long userId);

    /**
     * 获取家庭成员列表
     * @param userId 当前用户ID
     * @return 成员列表
     */
    List<FamilyMemberUserResponse> getFamilyMembers(Long userId);

    /**
     * 移除家庭成员
     * @param adminId 管理员用户ID
     * @param targetUserId 要移除的用户ID
     */
    void removeMember(Long adminId, Long targetUserId);

    /**
     * 更新家庭名称
     * @param userId 用户ID
     * @param familyName 新家庭名称
     */
    void updateFamilyName(Long userId, String familyName);

    /**
     * 生成唯一的家庭邀请码
     * @return 6位邀请码
     */
    String generateFamilyCode();
}
