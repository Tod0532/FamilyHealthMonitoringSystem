package com.health.service;

import com.health.interfaces.dto.HealthDataRequest;
import com.health.interfaces.dto.HealthDataResponse;
import com.health.interfaces.dto.HealthStatsResponse;

import java.util.List;

/**
 * 健康数据服务接口
 */
public interface HealthDataService {

    /**
     * 获取健康数据列表
     */
    List<HealthDataResponse> getList(Long userId, Long memberId, String dataType, String startDate, String endDate, Integer page, Integer size);

    /**
     * 根据ID获取数据详情
     */
    HealthDataResponse getById(Long id, Long userId);

    /**
     * 添加健康数据
     */
    HealthDataResponse create(Long userId, HealthDataRequest request);

    /**
     * 批量添加健康数据
     */
    List<HealthDataResponse> batchCreate(Long userId, List<HealthDataRequest> requests);

    /**
     * 更新健康数据
     */
    HealthDataResponse update(Long id, Long userId, HealthDataRequest request);

    /**
     * 删除健康数据
     */
    void delete(Long id, Long userId);

    /**
     * 获取数据统计
     */
    HealthStatsResponse getStats(Long userId, Long memberId, String dataType, String startDate, String endDate);

    /**
     * 获取最近7天趋势
     */
    List<HealthStatsResponse.TrendData> getTrend(Long userId, Long memberId, String dataType);

    /**
     * 清除用户数据
     */
    void clearUserData(Long userId);
}
