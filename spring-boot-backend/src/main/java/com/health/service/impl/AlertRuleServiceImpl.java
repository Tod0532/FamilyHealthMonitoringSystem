package com.health.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.health.domain.entity.AlertRule;
import com.health.domain.mapper.AlertRuleMapper;
import com.health.exception.BusinessException;
import com.health.exception.ErrorCode;
import com.health.interfaces.dto.AlertRuleRequest;
import com.health.interfaces.dto.AlertRuleResponse;
import com.health.service.AlertRuleService;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.BeanUtils;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.util.ArrayList;
import java.util.List;

/**
 * 预警规则服务实现
 */
@Service
@RequiredArgsConstructor
public class AlertRuleServiceImpl implements AlertRuleService {

    private final AlertRuleMapper alertRuleMapper;

    @Override
    public List<AlertRuleResponse> getList(Long userId) {
        LambdaQueryWrapper<AlertRule> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(AlertRule::getUserId, userId);
        wrapper.orderByAsc(AlertRule::getAlertType)
                .orderByDesc(AlertRule::getAlertLevel);

        List<AlertRule> list = alertRuleMapper.selectList(wrapper);
        return list.stream()
                .map(this::toResponse)
                .toList();
    }

    @Override
    public List<AlertRuleResponse> getEnabledList(Long userId) {
        LambdaQueryWrapper<AlertRule> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(AlertRule::getUserId, userId);
        wrapper.eq(AlertRule::getEnabled, 1);

        List<AlertRule> list = alertRuleMapper.selectList(wrapper);
        return list.stream()
                .map(this::toResponse)
                .toList();
    }

    @Override
    public AlertRuleResponse getById(Long id, Long userId) {
        AlertRule rule = alertRuleMapper.selectById(id);
        if (rule == null || !rule.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.RULE_NOT_FOUND, "规则不存在");
        }
        return toResponse(rule);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public AlertRuleResponse create(Long userId, AlertRuleRequest request) {
        // 校验参数
        validateRuleRequest(request);

        AlertRule rule = new AlertRule();
        BeanUtils.copyProperties(request, rule);
        rule.setUserId(userId);
        rule.setEnabled(request.getEnabled() != null ? request.getEnabled() : 1);
        rule.setIsDefault(0);

        alertRuleMapper.insert(rule);
        return toResponse(rule);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public AlertRuleResponse update(Long id, Long userId, AlertRuleRequest request) {
        AlertRule rule = alertRuleMapper.selectById(id);
        if (rule == null || !rule.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.RULE_NOT_FOUND, "规则不存在");
        }

        // 系统默认规则只能修改启用状态
        if (rule.getIsDefault() == 1) {
            if (request.getEnabled() != null) {
                rule.setEnabled(request.getEnabled());
            }
        } else {
            BeanUtils.copyProperties(request, rule, "id", "userId", "isDefault");
            if (request.getEnabled() != null) {
                rule.setEnabled(request.getEnabled());
            }
        }

        alertRuleMapper.updateById(rule);
        return toResponse(rule);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void delete(Long id, Long userId) {
        AlertRule rule = alertRuleMapper.selectById(id);
        if (rule == null || !rule.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.RULE_NOT_FOUND, "规则不存在");
        }
        if (rule.getIsDefault() == 1) {
            throw new BusinessException(ErrorCode.INVALID_PARAM, "系统默认规则不能删除");
        }
        alertRuleMapper.deleteById(id);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void toggleEnabled(Long id, Long userId, Integer enabled) {
        AlertRule rule = alertRuleMapper.selectById(id);
        if (rule == null || !rule.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.RULE_NOT_FOUND, "规则不存在");
        }
        rule.setEnabled(enabled);
        alertRuleMapper.updateById(rule);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void initDefaultRules(Long userId) {
        // 检查是否已有默认规则
        Long count = alertRuleMapper.selectCount(
                new LambdaQueryWrapper<AlertRule>()
                        .eq(AlertRule::getUserId, userId)
                        .eq(AlertRule::getIsDefault, 1)
        );
        if (count > 0) {
            return;
        }

        List<AlertRule> defaultRules = new ArrayList<>();

        // 血压高压预警
        AlertRule bpHigh = new AlertRule();
        bpHigh.setUserId(userId);
        bpHigh.setAlertType("blood_pressure");
        bpHigh.setAlertLevel("danger");
        bpHigh.setConditionType("gt");
        bpHigh.setThreshold1(140.0);
        bpHigh.setRuleName("血压高压预警");
        bpHigh.setEnabled(1);
        bpHigh.setIsDefault(1);
        defaultRules.add(bpHigh);

        // 血压低压预警
        AlertRule bpLow = new AlertRule();
        bpLow.setUserId(userId);
        bpLow.setAlertType("blood_pressure");
        bpLow.setAlertLevel("warning");
        bpLow.setConditionType("lt");
        bpLow.setThreshold1(90.0);
        bpLow.setRuleName("血压低压预警");
        bpLow.setEnabled(1);
        bpLow.setIsDefault(1);
        defaultRules.add(bpLow);

        // 心率过快预警
        AlertRule hrHigh = new AlertRule();
        hrHigh.setUserId(userId);
        hrHigh.setAlertType("heart_rate");
        hrHigh.setAlertLevel("danger");
        hrHigh.setConditionType("gt");
        hrHigh.setThreshold1(100.0);
        hrHigh.setRuleName("心率过快预警");
        hrHigh.setEnabled(1);
        hrHigh.setIsDefault(1);
        defaultRules.add(hrHigh);

        // 心率过缓预警
        AlertRule hrLow = new AlertRule();
        hrLow.setUserId(userId);
        hrLow.setAlertType("heart_rate");
        hrLow.setAlertLevel("warning");
        hrLow.setConditionType("lt");
        hrLow.setThreshold1(60.0);
        hrLow.setRuleName("心率过缓预警");
        hrLow.setEnabled(1);
        hrLow.setIsDefault(1);
        defaultRules.add(hrLow);

        // 血糖过高预警
        AlertRule bsHigh = new AlertRule();
        bsHigh.setUserId(userId);
        bsHigh.setAlertType("blood_sugar");
        bsHigh.setAlertLevel("danger");
        bsHigh.setConditionType("gt");
        bsHigh.setThreshold1(11.1);
        bsHigh.setRuleName("血糖过高预警");
        bsHigh.setEnabled(1);
        bsHigh.setIsDefault(1);
        defaultRules.add(bsHigh);

        // 体温发热预警
        AlertRule tempHigh = new AlertRule();
        tempHigh.setUserId(userId);
        tempHigh.setAlertType("temperature");
        tempHigh.setAlertLevel("warning");
        tempHigh.setConditionType("gt");
        tempHigh.setThreshold1(37.3);
        tempHigh.setRuleName("体温发热预警");
        tempHigh.setEnabled(1);
        tempHigh.setIsDefault(1);
        defaultRules.add(tempHigh);

        for (AlertRule rule : defaultRules) {
            alertRuleMapper.insert(rule);
        }
    }

    /**
     * 转换为响应对象
     */
    private AlertRuleResponse toResponse(AlertRule rule) {
        AlertRuleResponse response = new AlertRuleResponse();
        BeanUtils.copyProperties(rule, response);

        response.setAlertTypeLabel(getAlertTypeLabel(rule.getAlertType()));
        response.setAlertLevelLabel(getAlertLevelLabel(rule.getAlertLevel()));
        response.setConditionDesc(getConditionDesc(rule));

        return response;
    }

    private String getAlertTypeLabel(String alertType) {
        return switch (alertType) {
            case "blood_pressure" -> "血压";
            case "heart_rate" -> "心率";
            case "blood_sugar" -> "血糖";
            case "temperature" -> "体温";
            case "weight" -> "体重";
            default -> alertType;
        };
    }

    private String getAlertLevelLabel(String alertLevel) {
        return switch (alertLevel) {
            case "info" -> "提示";
            case "warning" -> "警告";
            case "danger" -> "危险";
            default -> alertLevel;
        };
    }

    private String getConditionDesc(AlertRule rule) {
        String unit = getUnit(rule.getAlertType());
        return switch (rule.getConditionType()) {
            case "gt" -> "大于 " + rule.getThreshold1() + unit;
            case "lt" -> "小于 " + rule.getThreshold1() + unit;
            case "eq" -> "等于 " + rule.getThreshold1() + unit;
            case "between" -> rule.getThreshold1() + unit + " ~ " + rule.getThreshold2() + unit;
            default -> rule.getConditionType();
        };
    }

    private String getUnit(String alertType) {
        return switch (alertType) {
            case "blood_pressure" -> "mmHg";
            case "heart_rate" -> "次/分";
            case "blood_sugar" -> "mmol/L";
            case "temperature" -> "℃";
            case "weight" -> "kg";
            default -> "";
        };
    }

    /**
     * 校验规则请求参数
     */
    private void validateRuleRequest(AlertRuleRequest request) {
        if (!StringUtils.hasText(request.getAlertType())) {
            throw new BusinessException(ErrorCode.INVALID_PARAM, "预警类型不能为空");
        }
        if (!StringUtils.hasText(request.getAlertLevel())) {
            throw new BusinessException(ErrorCode.INVALID_PARAM, "预警级别不能为空");
        }
        if (!StringUtils.hasText(request.getConditionType())) {
            throw new BusinessException(ErrorCode.INVALID_PARAM, "条件类型不能为空");
        }
        if (request.getThreshold1() == null) {
            throw new BusinessException(ErrorCode.INVALID_PARAM, "阈值不能为空");
        }
        // between类型需要两个阈值
        if ("between".equals(request.getConditionType()) && request.getThreshold2() == null) {
            throw new BusinessException(ErrorCode.INVALID_PARAM, "区间类型需要设置两个阈值");
        }
    }
}
