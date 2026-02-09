package com.health.interfaces.controller;

import com.health.interfaces.dto.*;
import com.health.interfaces.response.ApiResponse;
import com.health.service.FamilyService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import javax.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.*;

import javax.servlet.http.HttpServletRequest;
import java.util.List;

/**
 * 家庭控制器
 */
@Slf4j
@RestController
@RequiredArgsConstructor
@Tag(name = "家庭管理", description = "家庭创建、加入、成员管理")
public class FamilyController {

    private final FamilyService familyService;

    /**
     * 创建家庭
     */
    @PostMapping("/api/family/create")
    @Operation(summary = "创建家庭", description = "创建新家庭，当前用户自动成为管理员")
    public ApiResponse<FamilyResponse> createFamily(
            @Parameter(description = "用户ID", required = true)
            @RequestHeader("X-User-Id") Long userId,
            @Valid @RequestBody FamilyCreateRequest request) {
        log.info("创建家庭: userId={}, familyName={}", userId, request.getFamilyName());
        FamilyResponse response = familyService.createFamily(userId, request);
        return ApiResponse.success("家庭创建成功", response);
    }

    /**
     * 获取我的家庭信息
     */
    @GetMapping("/api/family/my")
    @Operation(summary = "获取我的家庭", description = "获取当前用户所在的家庭信息")
    public ApiResponse<FamilyResponse> getMyFamily(
            @Parameter(description = "用户ID", required = true)
            @RequestHeader("X-User-Id") Long userId) {
        log.info("获取我的家庭: userId={}", userId);
        FamilyResponse response = familyService.getMyFamily(userId);
        return ApiResponse.success(response);
    }

    /**
     * 获取家庭二维码
     */
    @GetMapping("/api/family/qrcode")
    @Operation(summary = "获取家庭二维码", description = "获取家庭邀请二维码（仅管理员）")
    public ApiResponse<FamilyQrCodeResponse> getQrCode(
            @Parameter(description = "用户ID", required = true)
            @RequestHeader("X-User-Id") Long userId) {
        log.info("获取家庭二维码: userId={}", userId);
        FamilyQrCodeResponse response = familyService.getQrCode(userId);
        return ApiResponse.success(response);
    }

    /**
     * 解析邀请码
     */
    @GetMapping("/api/family/info/{code}")
    @Operation(summary = "解析邀请码", description = "根据邀请码获取家庭信息（扫码后预览）")
    public ApiResponse<FamilyResponse> parseInviteCode(
            @Parameter(description = "邀请码", required = true)
            @PathVariable String code) {
        log.info("解析邀请码: code={}", code);
        FamilyResponse response = familyService.parseInviteCode(code);
        return ApiResponse.success(response);
    }

    /**
     * 加入家庭
     */
    @PostMapping("/api/family/join")
    @Operation(summary = "加入家庭", description = "通过邀请码加入家庭")
    public ApiResponse<FamilyResponse> joinFamily(
            @Parameter(description = "用户ID", required = true)
            @RequestHeader("X-User-Id") Long userId,
            @Valid @RequestBody FamilyJoinRequest request) {
        log.info("加入家庭: userId={}, inviteCode={}", userId, request.getInviteCode());
        FamilyResponse response = familyService.joinFamily(userId, request);
        return ApiResponse.success("成功加入家庭", response);
    }

    /**
     * 退出家庭
     */
    @PostMapping("/api/family/leave")
    @Operation(summary = "退出家庭", description = "退出当前所在的家庭")
    public ApiResponse<Void> leaveFamily(
            @Parameter(description = "用户ID", required = true)
            @RequestHeader("X-User-Id") Long userId) {
        log.info("退出家庭: userId={}", userId);
        familyService.leaveFamily(userId);
        return ApiResponse.success("已退出家庭", null);
    }

    /**
     * 获取家庭成员列表
     */
    @GetMapping("/api/family/members")
    @Operation(summary = "获取家庭成员", description = "获取当前家庭的所有成员列表")
    public ApiResponse<List<FamilyMemberUserResponse>> getFamilyMembers(HttpServletRequest request) {
        Long userId = com.health.util.SecurityUtil.getUserId(request);
        log.info("获取家庭成员列表: userId={}", userId);
        List<FamilyMemberUserResponse> response = familyService.getFamilyMembers(userId);
        return ApiResponse.success(response);
    }

    /**
     * 移除家庭成员
     */
    @DeleteMapping("/api/family/members/{targetUserId}")
    @Operation(summary = "移除家庭成员", description = "管理员移除指定成员")
    public ApiResponse<Void> removeMember(
            @Parameter(description = "管理员用户ID", required = true)
            @RequestHeader("X-User-Id") Long adminId,
            @Parameter(description = "要移除的用户ID", required = true)
            @PathVariable Long targetUserId) {
        log.info("移除家庭成员: adminId={}, targetUserId={}", adminId, targetUserId);
        familyService.removeMember(adminId, targetUserId);
        return ApiResponse.success("成员已移除", null);
    }

    /**
     * 更新家庭名称
     */
    @PutMapping("/api/family/name")
    @Operation(summary = "更新家庭名称", description = "管理员更新家庭名称")
    public ApiResponse<Void> updateFamilyName(
            @Parameter(description = "用户ID", required = true)
            @RequestHeader("X-User-Id") Long userId,
            @org.springframework.web.bind.annotation.RequestBody @Valid FamilyUpdateNameRequest request) {
        log.info("更新家庭名称: userId={}, familyName={}", userId, request.getFamilyName());
        familyService.updateFamilyName(userId, request.getFamilyName());
        return ApiResponse.success("家庭名称已更新", null);
    }

    /**
     * 更新家庭名称（使用RequestParam）
     */
    @PostMapping("/api/family/update-name")
    @Operation(summary = "更新家庭名称", description = "管理员更新家庭名称（备用接口）")
    public ApiResponse<Void> updateFamilyNameV2(
            @Parameter(description = "用户ID", required = true)
            @RequestHeader("X-User-Id") Long userId,
            @Parameter(description = "新家庭名称", required = true)
            @RequestParam(name = "familyName") String familyName) {
        log.info("更新家庭名称V2: userId={}, familyName={}", userId, familyName);
        familyService.updateFamilyName(userId, familyName);
        return ApiResponse.success("家庭名称已更新", null);
    }
}
