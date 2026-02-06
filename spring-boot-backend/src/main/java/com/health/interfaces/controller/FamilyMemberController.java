package com.health.interfaces.controller;

import com.health.config.RequireRole;
import com.health.interfaces.dto.FamilyMemberRequest;
import com.health.interfaces.dto.FamilyMemberResponse;
import com.health.interfaces.response.ApiResponse;
import com.health.service.FamilyMemberService;
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
 * 家庭成员控制器
 */
@Tag(name = "家庭成员管理", description = "家庭成员的增删改查接口")
@RestController
@RequestMapping("/api/members")
@RequiredArgsConstructor
public class FamilyMemberController {

    private final FamilyMemberService familyMemberService;

    @Operation(summary = "获取家庭成员列表")
    @GetMapping
    public ApiResponse<List<FamilyMemberResponse>> getList(HttpServletRequest request) {
        Long userId = SecurityUtil.getUserId(request);
        List<FamilyMemberResponse> list = familyMemberService.getList(userId);
        return ApiResponse.success(list);
    }

    @Operation(summary = "获取成员详情")
    @GetMapping("/{id}")
    public ApiResponse<FamilyMemberResponse> getById(
            @Parameter(description = "成员ID") @PathVariable Long id,
            HttpServletRequest request) {
        Long userId = SecurityUtil.getUserId(request);
        FamilyMemberResponse response = familyMemberService.getById(id, userId);
        return ApiResponse.success(response);
    }

    @Operation(summary = "添加家庭成员")
    @PostMapping
    @RequireRole("ADMIN")
    public ApiResponse<FamilyMemberResponse> create(
            @Valid @RequestBody FamilyMemberRequest memberRequest,
            HttpServletRequest request) {
        Long userId = SecurityUtil.getUserId(request);
        FamilyMemberResponse response = familyMemberService.create(userId, memberRequest);
        return ApiResponse.success(response);
    }

    @Operation(summary = "更新家庭成员")
    @PutMapping("/{id}")
    @RequireRole("ADMIN")
    public ApiResponse<FamilyMemberResponse> update(
            @Parameter(description = "成员ID") @PathVariable Long id,
            @Valid @RequestBody FamilyMemberRequest memberRequest,
            HttpServletRequest request) {
        Long userId = SecurityUtil.getUserId(request);
        FamilyMemberResponse response = familyMemberService.update(id, userId, memberRequest);
        return ApiResponse.success(response);
    }

    @Operation(summary = "删除家庭成员")
    @DeleteMapping("/{id}")
    @RequireRole("ADMIN")
    public ApiResponse<Void> delete(
            @Parameter(description = "成员ID") @PathVariable Long id,
            HttpServletRequest request) {
        Long userId = SecurityUtil.getUserId(request);
        familyMemberService.delete(id, userId);
        return ApiResponse.success();
    }

    @Operation(summary = "批量删除家庭成员")
    @DeleteMapping("/batch")
    @RequireRole("ADMIN")
    public ApiResponse<Void> batchDelete(
            @RequestBody List<Long> ids,
            HttpServletRequest request) {
        Long userId = SecurityUtil.getUserId(request);
        familyMemberService.batchDelete(ids, userId);
        return ApiResponse.success();
    }
}
