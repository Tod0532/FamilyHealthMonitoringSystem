package com.health.interfaces.controller;

import com.health.interfaces.dto.AlertRuleRequest;
import com.health.interfaces.dto.AlertRuleResponse;
import com.health.interfaces.response.ApiResponse;
import com.health.service.AlertRuleService;
import com.health.util.SecurityUtil;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import javax.servlet.http.HttpServletRequest;
import javax.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * 预警规则控制器
 */
@Tag(name = "预警规则管理", description = "预警规则的增删改查接口")
@RestController
@RequestMapping("/api/alert-rules")
@RequiredArgsConstructor
public class AlertRuleController {

    private final AlertRuleService alertRuleService;

    @Operation(summary = "获取预警规则列表")
    @GetMapping
    public ApiResponse<List<AlertRuleResponse>> getList(HttpServletRequest request) {
        Long userId = SecurityUtil.getUserId(request);
        List<AlertRuleResponse> list = alertRuleService.getList(userId);
        return ApiResponse.success(list);
    }

    @Operation(summary = "获取启用的预警规则列表")
    @GetMapping("/enabled")
    public ApiResponse<List<AlertRuleResponse>> getEnabledList(HttpServletRequest request) {
        Long userId = SecurityUtil.getUserId(request);
        List<AlertRuleResponse> list = alertRuleService.getEnabledList(userId);
        return ApiResponse.success(list);
    }

    @Operation(summary = "获取规则详情")
    @GetMapping("/{id}")
    public ApiResponse<AlertRuleResponse> getById(
            @Parameter(description = "规则ID") @PathVariable Long id,
            HttpServletRequest request) {
        Long userId = SecurityUtil.getUserId(request);
        AlertRuleResponse response = alertRuleService.getById(id, userId);
        return ApiResponse.success(response);
    }

    @Operation(summary = "添加预警规则")
    @PostMapping
    public ApiResponse<AlertRuleResponse> create(
            @Valid @RequestBody AlertRuleRequest ruleRequest,
            HttpServletRequest request) {
        Long userId = SecurityUtil.getUserId(request);
        AlertRuleResponse response = alertRuleService.create(userId, ruleRequest);
        return ApiResponse.success(response);
    }

    @Operation(summary = "更新预警规则")
    @PutMapping("/{id}")
    public ApiResponse<AlertRuleResponse> update(
            @Parameter(description = "规则ID") @PathVariable Long id,
            @Valid @RequestBody AlertRuleRequest ruleRequest,
            HttpServletRequest request) {
        Long userId = SecurityUtil.getUserId(request);
        AlertRuleResponse response = alertRuleService.update(id, userId, ruleRequest);
        return ApiResponse.success(response);
    }

    @Operation(summary = "删除预警规则")
    @DeleteMapping("/{id}")
    public ApiResponse<Void> delete(
            @Parameter(description = "规则ID") @PathVariable Long id,
            HttpServletRequest request) {
        Long userId = SecurityUtil.getUserId(request);
        alertRuleService.delete(id, userId);
        return ApiResponse.success();
    }

    @Operation(summary = "启用/禁用规则")
    @PutMapping("/{id}/toggle")
    public ApiResponse<Void> toggleEnabled(
            @Parameter(description = "规则ID") @PathVariable Long id,
            @Parameter(description = "启用状态：0-禁用，1-启用") @RequestParam Integer enabled,
            HttpServletRequest request) {
        Long userId = SecurityUtil.getUserId(request);
        alertRuleService.toggleEnabled(id, userId, enabled);
        return ApiResponse.success();
    }

    @Operation(summary = "初始化默认规则")
    @PostMapping("/init")
    public ApiResponse<Void> initDefaultRules(HttpServletRequest request) {
        Long userId = SecurityUtil.getUserId(request);
        alertRuleService.initDefaultRules(userId);
        return ApiResponse.success();
    }
}
