package com.health.domain.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 已接入的设备（如 ESP32 手环心率桥）
 *
 * 设计要点：
 *  · 只保存 deviceToken 的哈希，防止拖库后他人伪造上报
 *  · 绑定码一次性、限时有效，绑定成功后清空
 *  · 令牌权限最小化：只能写健康数据，不能读
 */
@Data
@TableName("device")
public class Device {

    @TableId(type = IdType.ASSIGN_ID)
    private Long id;

    /** 归属用户 */
    private Long userId;

    /** 数据归属的家庭成员（family_member.id） */
    private Long memberId;

    /** 设备序列号（唯一） */
    private String deviceSn;

    private String deviceName;

    /** 设备类型：esp32_hr_bridge 等 */
    private String deviceType;

    /** 令牌哈希（SHA-256），不存明文 */
    private String tokenHash;

    /** 一次性绑定码，绑定成功后置空 */
    private String bindCode;

    private LocalDateTime bindCodeExpire;

    private LocalDateTime lastSeen;

    /** 1 正常 0 已解绑 */
    private Integer status;

    private String firmwareVersion;

    private LocalDateTime createTime;
}
