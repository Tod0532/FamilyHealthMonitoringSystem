package com.health.service;

import com.health.interfaces.dto.AlertRuleRequest;
import com.health.interfaces.dto.AlertRuleResponse;

import java.util.List;

/**
 * 预警规则服务接口
 */
public interface AlertRuleService {

    /**
     * 获取用户的预警规则列表
     */
    List<AlertRuleResponse> getList(Long userId);

    /**
     * 获取启用的预警规则列表
     */
    List<AlertRuleResponse> getEnabledList(Long userId);

    /**
     * 根据ID获取规则详情
     */
    AlertRuleResponse getById(Long id, Long userId);

    /**
     * 添加预警规则
     */
    AlertRuleResponse create(Long userId, AlertRuleRequest request);

    /**
     * 更新预警规则
     */
    AlertRuleResponse update(Long id, Long userId, AlertRuleRequest request);

    /**
     * 删除预警规则
     */
    void delete(Long id, Long userId);

    /**
     * 启用/禁用规则
     */
    void toggleEnabled(Long id, Long userId, Integer enabled);

    /**
     * 初始化默认规则
     */
    void initDefaultRules(Long userId);
}
