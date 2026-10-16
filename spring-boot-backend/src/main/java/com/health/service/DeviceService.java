package com.health.service;

import com.health.domain.entity.Device;
import com.health.interfaces.dto.DeviceDtos;

import java.util.List;

/**
 * 设备接入服务
 *
 * 鉴权模型：App 生成一次性绑定码 → 设备用绑定码换取设备令牌 →
 * 设备令牌只能调用上报类接口（最小权限），App 可随时解绑使其失效。
 */
public interface DeviceService {

    /** App：为指定成员生成一次性绑定码（默认 10 分钟有效） */
    DeviceDtos.BindCodeResponse createBindCode(Long userId, DeviceDtos.BindCodeRequest req);

    /** 设备：用绑定码换取设备令牌；同一序列号重复绑定则轮换令牌 */
    DeviceDtos.BindResponse bind(DeviceDtos.BindRequest req);

    /** 设备：上报一条健康数据（心率等），内部写入 health_data */
    void report(String deviceToken, DeviceDtos.DeviceReportRequest req);

    /** 设备：心跳，用于 App 显示在线状态 */
    void heartbeat(String deviceToken, String firmwareVersion);

    /** App：查看自己已绑定的设备 */
    List<DeviceDtos.DeviceVO> listMine(Long userId);

    /** App：解绑（令牌立即失效） */
    void unbind(Long userId, Long deviceId);

    /** App：各设备最近一次上报（供心率实时监控轮询） */
    List<DeviceDtos.DeviceLatestVO> listLatest(Long userId);

    /** 内部：按令牌取设备，失败抛业务异常 */
    Device requireByToken(String deviceToken);
}
