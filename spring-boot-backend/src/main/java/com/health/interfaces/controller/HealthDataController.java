package com.health.interfaces.controller;

import com.health.interfaces.dto.HealthDataRequest;
import com.health.interfaces.dto.HealthDataResponse;
import com.health.interfaces.dto.HealthStatsResponse;
import com.health.interfaces.response.ApiResponse;
import com.health.service.HealthDataService;
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
 * 健康数据控制器
 */
@Tag(name = "健康数据管理", description = "健康数据的记录、查询和统计接口")
@RestController
@RequestMapping("/api/health-data")
@RequiredArgsConstructor
public class HealthDataController {

    private final HealthDataService healthDataService;

    @Operation(summary = "获取健康数据列表")
    @GetMapping
    public ApiResponse<List<HealthDataResponse>> getList(
            @Parameter(description = "成员ID") @RequestParam(required = false) Long memberId,
            @Parameter(description = "数据类型") @RequestParam(required = false) String dataType,
            @Parameter(description = "开始日期 yyyy-MM-dd") @RequestParam(required = false) String startDate,
            @Parameter(description = "结束日期 yyyy-MM-dd") @RequestParam(required = false) String endDate,
            @Parameter(description = "页码") @RequestParam(required = false) Integer page,
            @Parameter(description = "每页大小") @RequestParam(required = false) Integer size,
            HttpServletRequest request) {
        Long userId = SecurityUtil.getUserId(request);
        List<HealthDataResponse> list = healthDataService.getList(userId, memberId, dataType, startDate, endDate, page, size);
        return ApiResponse.success(list);
    }

    @Operation(summary = "获取数据详情")
    @GetMapping("/{id}")
    public ApiResponse<HealthDataResponse> getById(
            @Parameter(description = "数据ID") @PathVariable Long id,
            HttpServletRequest request) {
        Long userId = SecurityUtil.getUserId(request);
        HealthDataResponse response = healthDataService.getById(id, userId);
        return ApiResponse.success(response);
    }

    @Operation(summary = "添加健康数据")
    @PostMapping
    public ApiResponse<HealthDataResponse> create(
            @Valid @RequestBody HealthDataRequest dataRequest,
            HttpServletRequest request) {
        Long userId = SecurityUtil.getUserId(request);
        HealthDataResponse response = healthDataService.create(userId, dataRequest);
        return ApiResponse.success(response);
    }

    @Operation(summary = "批量添加健康数据")
    @PostMapping("/batch")
    public ApiResponse<List<HealthDataResponse>> batchCreate(
            @Valid @RequestBody List<HealthDataRequest> dataRequests,
            HttpServletRequest request) {
        Long userId = SecurityUtil.getUserId(request);
        List<HealthDataResponse> responses = healthDataService.batchCreate(userId, dataRequests);
        return ApiResponse.success(responses);
    }

    @Operation(summary = "更新健康数据")
    @PutMapping("/{id}")
    public ApiResponse<HealthDataResponse> update(
            @Parameter(description = "数据ID") @PathVariable Long id,
            @Valid @RequestBody HealthDataRequest dataRequest,
            HttpServletRequest request) {
        Long userId = SecurityUtil.getUserId(request);
        HealthDataResponse response = healthDataService.update(id, userId, dataRequest);
        return ApiResponse.success(response);
    }

    @Operation(summary = "删除健康数据")
    @DeleteMapping("/{id}")
    public ApiResponse<Void> delete(
            @Parameter(description = "数据ID") @PathVariable Long id,
            HttpServletRequest request) {
        Long userId = SecurityUtil.getUserId(request);
        healthDataService.delete(id, userId);
        return ApiResponse.success();
    }

    @Operation(summary = "获取数据统计")
    @GetMapping("/stats")
    public ApiResponse<HealthStatsResponse> getStats(
            @Parameter(description = "成员ID") @RequestParam(required = false) Long memberId,
            @Parameter(description = "数据类型") @RequestParam(required = false) String dataType,
            @Parameter(description = "开始日期 yyyy-MM-dd") @RequestParam(required = false) String startDate,
            @Parameter(description = "结束日期 yyyy-MM-dd") @RequestParam(required = false) String endDate,
            HttpServletRequest request) {
        Long userId = SecurityUtil.getUserId(request);
        HealthStatsResponse stats = healthDataService.getStats(userId, memberId, dataType, startDate, endDate);
        return ApiResponse.success(stats);
    }

    @Operation(summary = "获取最近7天趋势")
    @GetMapping("/trend")
    public ApiResponse<List<HealthStatsResponse.TrendData>> getTrend(
            @Parameter(description = "成员ID") @RequestParam(required = false) Long memberId,
            @Parameter(description = "数据类型") @RequestParam(required = false) String dataType,
            HttpServletRequest request) {
        Long userId = SecurityUtil.getUserId(request);
        List<HealthStatsResponse.TrendData> trend = healthDataService.getTrend(userId, memberId, dataType);
        return ApiResponse.success(trend);
    }
}
