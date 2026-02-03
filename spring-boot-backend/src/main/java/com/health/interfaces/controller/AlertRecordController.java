package com.health.interfaces.controller;

import com.health.interfaces.dto.AlertRecordResponse;
import com.health.interfaces.response.ApiResponse;
import com.health.service.AlertRecordService;
import com.health.util.SecurityUtil;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import javax.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * 预警记录控制器
 */
@Tag(name = "预警记录管理", description = "预警记录的查询和处理接口")
@RestController
@RequestMapping("/api/alert-records")
@RequiredArgsConstructor
public class AlertRecordController {

    private final AlertRecordService alertRecordService;

    @Operation(summary = "获取预警记录列表")
    @GetMapping
    public ApiResponse<List<AlertRecordResponse>> getList(
            @Parameter(description = "成员ID") @RequestParam(required = false) Long memberId,
            @Parameter(description = "状态") @RequestParam(required = false) String status,
            @Parameter(description = "页码") @RequestParam(required = false) Integer page,
            @Parameter(description = "每页大小") @RequestParam(required = false) Integer size,
            HttpServletRequest request) {
        Long userId = SecurityUtil.getUserId(request);
        List<AlertRecordResponse> list = alertRecordService.getList(userId, memberId, status, page, size);
        return ApiResponse.success(list);
    }

    @Operation(summary = "获取未读记录数量")
    @GetMapping("/unread-count")
    public ApiResponse<Long> getUnreadCount(HttpServletRequest request) {
        Long userId = SecurityUtil.getUserId(request);
        Long count = alertRecordService.getUnreadCount(userId);
        return ApiResponse.success(count);
    }

    @Operation(summary = "标记为已读")
    @PutMapping("/{id}/read")
    public ApiResponse<Void> markAsRead(
            @Parameter(description = "记录ID") @PathVariable Long id,
            HttpServletRequest request) {
        Long userId = SecurityUtil.getUserId(request);
        alertRecordService.markAsRead(id, userId);
        return ApiResponse.success();
    }

    @Operation(summary = "全部标记为已读")
    @PutMapping("/read-all")
    public ApiResponse<Void> markAllAsRead(HttpServletRequest request) {
        Long userId = SecurityUtil.getUserId(request);
        alertRecordService.markAllAsRead(userId);
        return ApiResponse.success();
    }

    @Operation(summary = "处理预警")
    @PutMapping("/{id}/handle")
    public ApiResponse<Void> handle(
            @Parameter(description = "记录ID") @PathVariable Long id,
            HttpServletRequest request) {
        Long userId = SecurityUtil.getUserId(request);
        alertRecordService.handle(id, userId);
        return ApiResponse.success();
    }

    @Operation(summary = "删除预警记录")
    @DeleteMapping("/{id}")
    public ApiResponse<Void> delete(
            @Parameter(description = "记录ID") @PathVariable Long id,
            HttpServletRequest request) {
        Long userId = SecurityUtil.getUserId(request);
        alertRecordService.delete(id, userId);
        return ApiResponse.success();
    }
}
