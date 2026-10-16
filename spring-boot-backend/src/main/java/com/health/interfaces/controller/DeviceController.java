package com.health.interfaces.controller;

import com.health.interfaces.response.ApiResponse;
import com.health.interfaces.dto.DeviceDtos;
import com.health.service.DeviceService;
import com.health.util.SecurityUtil;
import javax.servlet.http.HttpServletRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import javax.validation.Valid;
import java.util.List;

/**
 * 设备接入接口
 *
 * 两类调用方：
 *  · App（用用户 JWT）：生成绑定码、查看/解绑设备
 *  · 设备（用设备令牌，放在 X-Device-Token 头）：绑定、上报、心跳
 *
 * 设备令牌走单独的头部，不复用 Authorization，避免与用户 JWT 混淆；
 * 且设备端接口只提供"写"能力，读不了任何家庭数据（最小权限）。
 */
@Tag(name = "设备接入", description = "手环心率桥等硬件设备的绑定与数据上报")
@RestController
@RequestMapping("/api/device")
@RequiredArgsConstructor
public class DeviceController {

    private final DeviceService deviceService;

    @Operation(summary = "生成绑定码（App）")
    @PostMapping("/bind-code")
    public ApiResponse<DeviceDtos.BindCodeResponse> createBindCode(
            @Valid @RequestBody DeviceDtos.BindCodeRequest req,
            HttpServletRequest request) {
        return ApiResponse.success(deviceService.createBindCode(
                SecurityUtil.getUserId(request), req));
    }

    @Operation(summary = "查看已绑定设备（App）")
    @GetMapping
    public ApiResponse<List<DeviceDtos.DeviceVO>> list(HttpServletRequest request) {
        return ApiResponse.success(deviceService.listMine(SecurityUtil.getUserId(request)));
    }

    @Operation(summary = "各设备最近一次上报（App 心率实时监控轮询用）")
    @GetMapping("/latest")
    public ApiResponse<List<DeviceDtos.DeviceLatestVO>> latest(
            HttpServletRequest request) {
        return ApiResponse.success(
                deviceService.listLatest(SecurityUtil.getUserId(request)));
    }

    @Operation(summary = "解绑设备（App）")
    @DeleteMapping("/{id}")
    public ApiResponse<Void> unbind(@PathVariable Long id, HttpServletRequest request) {
        deviceService.unbind(SecurityUtil.getUserId(request), id);
        return ApiResponse.success();
    }

    @Operation(summary = "设备绑定（设备端，用绑定码换令牌）")
    @PostMapping("/bind")
    public ApiResponse<DeviceDtos.BindResponse> bind(
            @Valid @RequestBody DeviceDtos.BindRequest req) {
        return ApiResponse.success(deviceService.bind(req));
    }

    @Operation(summary = "设备上报健康数据（设备端）")
    @PostMapping("/health-data")
    public ApiResponse<Void> report(
            @RequestHeader(value = "X-Device-Token", required = false) String token,
            @Valid @RequestBody DeviceDtos.DeviceReportRequest req) {
        deviceService.report(token, req);
        return ApiResponse.success();
    }

    @Operation(summary = "设备心跳（设备端）")
    @PostMapping("/heartbeat")
    public ApiResponse<Void> heartbeat(
            @RequestHeader(value = "X-Device-Token", required = false) String token,
            @RequestParam(value = "firmwareVersion", required = false) String fw) {
        deviceService.heartbeat(token, fw);
        return ApiResponse.success();
    }
}
