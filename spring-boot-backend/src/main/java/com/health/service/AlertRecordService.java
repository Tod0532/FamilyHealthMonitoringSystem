package com.health.service;

import com.health.interfaces.dto.AlertRecordResponse;

import java.util.List;

/**
 * 预警记录服务接口
 */
public interface AlertRecordService {

    /**
     * 获取预警记录列表
     */
    List<AlertRecordResponse> getList(Long userId, Long memberId, String status, Integer page, Integer size);

    /**
     * 获取未读记录数量
     */
    Long getUnreadCount(Long userId);

    /**
     * 标记为已读
     */
    void markAsRead(Long id, Long userId);

    /**
     * 全部标记为已读
     */
    void markAllAsRead(Long userId);

    /**
     * 处理预警
     */
    void handle(Long id, Long userId);

    /**
     * 删除预警记录
     */
    void delete(Long id, Long userId);

    /**
     * 清除用户数据
     */
    void clearUserData(Long userId);
}
