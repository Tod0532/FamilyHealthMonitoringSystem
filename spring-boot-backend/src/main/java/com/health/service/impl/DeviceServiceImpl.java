package com.health.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.health.domain.entity.Device;
import com.health.domain.entity.FamilyMember;
import com.health.domain.entity.HealthData;
import com.health.domain.mapper.DeviceMapper;
import com.health.domain.mapper.FamilyMemberMapper;
import com.health.domain.mapper.HealthDataMapper;
import com.health.exception.BusinessException;
import com.health.exception.ErrorCode;
import com.health.interfaces.dto.DeviceDtos;
import com.health.service.DeviceService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.stream.Collectors;

/**
 * 设备接入服务实现
 *
 * 安全要点：
 *  1. 设备令牌只存 SHA-256 哈希，库里拿不到明文
 *  2. 绑定码一次性、10 分钟有效，绑定成功即作废
 *  3. 令牌权限最小化：只能通过 /api/device/** 写数据，无法读家庭数据
 *  4. 解绑即把 status 置 0，令牌立刻失效
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class DeviceServiceImpl implements DeviceService {

    private final DeviceMapper deviceMapper;
    private final FamilyMemberMapper familyMemberMapper;
    private final HealthDataMapper healthDataMapper;

    private static final SecureRandom RANDOM = new SecureRandom();
    private static final int BIND_CODE_MINUTES = 10;
    private static final DateTimeFormatter FMT =
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    @Override
    public DeviceDtos.BindCodeResponse createBindCode(Long userId,
                                                      DeviceDtos.BindCodeRequest req) {
        FamilyMember member = familyMemberMapper.selectById(req.getMemberId());
        if (member == null || !member.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "成员不存在或不属于当前用户");
        }

        // 6 位数字绑定码，避开容易混淆的 0/O、1/I（这里只用数字，直接随机）
        String code = String.format("%06d", RANDOM.nextInt(1_000_000));

        // 一个设备记录在"未绑定"阶段先落库，绑定成功后补令牌
        Device d = new Device();
        d.setUserId(userId);
        d.setMemberId(req.getMemberId());
        d.setDeviceSn("pending-" + System.currentTimeMillis() + "-" + code);
        d.setDeviceName(req.getDeviceName() == null ? "未命名设备" : req.getDeviceName());
        d.setDeviceType("esp32_hr_bridge");
        d.setBindCode(code);
        d.setBindCodeExpire(LocalDateTime.now().plusMinutes(BIND_CODE_MINUTES));
        d.setStatus(1);
        d.setCreateTime(LocalDateTime.now());
        deviceMapper.insert(d);

        DeviceDtos.BindCodeResponse resp = new DeviceDtos.BindCodeResponse();
        resp.setBindCode(code);
        resp.setExpireMinutes(BIND_CODE_MINUTES);
        resp.setMemberId(member.getId());
        resp.setMemberName(member.getName());
        log.info("用户 {} 生成设备绑定码 {}（成员 {}，{} 分钟内有效）",
                userId, code, member.getName(), BIND_CODE_MINUTES);
        return resp;
    }

    @Override
    @Transactional
    public DeviceDtos.BindResponse bind(DeviceDtos.BindRequest req) {
        // 优先复用该序列号已有的记录（重复配网/换绑）
        Device d = deviceMapper.selectOne(new LambdaQueryWrapper<Device>()
                .eq(Device::getDeviceSn, req.getDeviceSn())
                .orderByDesc(Device::getId)
                .last("limit 1"));

        Device codeHolder = deviceMapper.selectOne(new LambdaQueryWrapper<Device>()
                .eq(Device::getBindCode, req.getBindCode())
                .orderByDesc(Device::getId)
                .last("limit 1"));

        if (codeHolder == null || codeHolder.getBindCodeExpire() == null
                || codeHolder.getBindCodeExpire().isBefore(LocalDateTime.now())) {
            throw new BusinessException(ErrorCode.INVALID_PARAM, "绑定码无效或已过期");
        }

        // 令牌：32 字节随机数的十六进制
        byte[] raw = new byte[32];
        RANDOM.nextBytes(raw);
        StringBuilder sb = new StringBuilder();
        for (byte b : raw) {
            sb.append(String.format("%02x", b));
        }
        String token = sb.toString();

        final Device target;
        if (d != null && !"pending".equals(safeType(d))) {
            // 已存在的真实设备：换绑
            d.setUserId(codeHolder.getUserId());
            d.setMemberId(codeHolder.getMemberId());
            d.setTokenHash(sha256(token));
            d.setStatus(1);
            d.setLastSeen(LocalDateTime.now());
            d.setFirmwareVersion(req.getFirmwareVersion());
            if (req.getDeviceName() != null && !req.getDeviceName().isEmpty()) {
                d.setDeviceName(req.getDeviceName());
            }
            deviceMapper.updateById(d);
            target = d;
        } else {
            codeHolder.setDeviceSn(req.getDeviceSn());
            codeHolder.setDeviceName(req.getDeviceName() == null
                    ? codeHolder.getDeviceName() : req.getDeviceName());
            codeHolder.setDeviceType(req.getDeviceType() == null
                    ? "esp32_hr_bridge" : req.getDeviceType());
            codeHolder.setTokenHash(sha256(token));
            codeHolder.setFirmwareVersion(req.getFirmwareVersion());
            codeHolder.setLastSeen(LocalDateTime.now());
            // 绑定码用掉即作废
            codeHolder.setBindCode(null);
            codeHolder.setBindCodeExpire(null);
            deviceMapper.updateById(codeHolder);
            target = codeHolder;
        }

        FamilyMember member = familyMemberMapper.selectById(target.getMemberId());
        DeviceDtos.BindResponse resp = new DeviceDtos.BindResponse();
        resp.setDeviceToken(token);
        resp.setMemberId(target.getMemberId());
        resp.setMemberName(member == null ? "" : member.getName());
        resp.setServerTime(LocalDateTime.now().format(FMT));
        log.info("设备 {} 绑定成功，归属成员 {}", req.getDeviceSn(), target.getMemberId());
        return resp;
    }

    @Override
    @Transactional
    public void report(String deviceToken, DeviceDtos.DeviceReportRequest req) {
        Device d = requireByToken(deviceToken);

        HealthData data = new HealthData();
        data.setUserId(d.getUserId());
        data.setMemberId(d.getMemberId());
        // 必须带 family_id：健康数据列表是按 family_id 过滤的，
        // 漏写会导致记录虽已入库，但在 App 里完全看不到（实测踩到）。
        FamilyMember owner = familyMemberMapper.selectById(d.getMemberId());
        data.setFamilyId(owner == null ? null : owner.getFamilyId());
        data.setDataType(req.getDataType());
        data.setValue1(req.getValue1());
        data.setValue2(req.getValue2());
        data.setValue3(req.getValue3());
        data.setUnit(req.getUnit());
        data.setDataSource("device");
        data.setDeviceName(d.getDeviceName());
        data.setNotes("设备自动采集");
        data.setMeasureTime(parseTime(req.getMeasureTime()));
        data.setCreateTime(LocalDateTime.now());
        data.setUpdateTime(LocalDateTime.now());
        data.setDeleted(0);
        healthDataMapper.insert(data);

        d.setLastSeen(LocalDateTime.now());
        deviceMapper.updateById(d);
        log.info("设备 {} 上报 {}={}（成员 {}）",
                d.getDeviceSn(), req.getDataType(), req.getValue1(), d.getMemberId());
    }

    @Override
    public void heartbeat(String deviceToken, String firmwareVersion) {
        Device d = requireByToken(deviceToken);
        d.setLastSeen(LocalDateTime.now());
        if (firmwareVersion != null && !firmwareVersion.isEmpty()) {
            d.setFirmwareVersion(firmwareVersion);
        }
        deviceMapper.updateById(d);
    }

    @Override
    public List<DeviceDtos.DeviceVO> listMine(Long userId) {
        List<Device> list = deviceMapper.selectList(new LambdaQueryWrapper<Device>()
                .eq(Device::getUserId, userId)
                .eq(Device::getStatus, 1)
                .isNotNull(Device::getTokenHash)
                .orderByDesc(Device::getLastSeen));
        return list.stream().map(d -> {
            DeviceDtos.DeviceVO vo = new DeviceDtos.DeviceVO();
            vo.setId(d.getId());
            vo.setDeviceSn(d.getDeviceSn());
            vo.setDeviceName(d.getDeviceName());
            vo.setDeviceType(d.getDeviceType());
            vo.setMemberId(d.getMemberId());
            FamilyMember m = familyMemberMapper.selectById(d.getMemberId());
            vo.setMemberName(m == null ? "" : m.getName());
            vo.setLastSeen(d.getLastSeen() == null ? "" : d.getLastSeen().format(FMT));
            vo.setOnline(d.getLastSeen() != null
                    && d.getLastSeen().isAfter(LocalDateTime.now().minusMinutes(5)));
            vo.setFirmwareVersion(d.getFirmwareVersion());
            vo.setCreateTime(d.getCreateTime() == null ? "" : d.getCreateTime().format(FMT));
            return vo;
        }).collect(Collectors.toList());
    }

    @Override
    public List<DeviceDtos.DeviceLatestVO> listLatest(Long userId) {
        List<Device> devices = deviceMapper.selectList(new LambdaQueryWrapper<Device>()
                .eq(Device::getUserId, userId)
                .eq(Device::getStatus, 1)
                .isNotNull(Device::getTokenHash)
                .orderByDesc(Device::getLastSeen));
        final LocalDateTime now = LocalDateTime.now();
        List<DeviceDtos.DeviceLatestVO> out = new java.util.ArrayList<>();
        for (Device d : devices) {
            DeviceDtos.DeviceLatestVO vo = new DeviceDtos.DeviceLatestVO();
            vo.setDeviceId(d.getId());
            vo.setDeviceName(d.getDeviceName());
            vo.setMemberId(d.getMemberId());
            FamilyMember m = familyMemberMapper.selectById(d.getMemberId());
            vo.setMemberName(m == null ? "" : m.getName());
            vo.setOnline(d.getLastSeen() != null
                    && d.getLastSeen().isAfter(now.minusMinutes(5)));
            vo.setLastSeen(d.getLastSeen() == null ? "" : d.getLastSeen().format(FMT));

            // 该设备最近一次"设备来源"的心率记录
            HealthData latest = healthDataMapper.selectOne(new LambdaQueryWrapper<HealthData>()
                    .eq(HealthData::getMemberId, d.getMemberId())
                    .eq(HealthData::getDataType, "heart_rate")
                    .eq(HealthData::getDataSource, "device")
                    .orderByDesc(HealthData::getMeasureTime)
                    .last("limit 1"));
            if (latest != null) {
                vo.setHeartRate(latest.getValue1());
                vo.setMeasureTime(latest.getMeasureTime() == null
                        ? "" : latest.getMeasureTime().format(FMT));
                if (latest.getMeasureTime() != null) {
                    final long age = java.time.Duration.between(
                            latest.getMeasureTime(), now).getSeconds();
                    vo.setAgeSeconds(Math.max(0, age));
                    // 超过 20 秒没有新值即视为陈旧：宁可显示"已断开"，
                    // 也不要把几分钟前的旧读数当成实时值（会误判健康状况）
                    vo.setStale(age > 20);
                } else {
                    vo.setStale(true);
                }
            } else {
                vo.setStale(true);
            }
            out.add(vo);
        }
        return out;
    }

    @Override
    public void unbind(Long userId, Long deviceId) {
        Device d = deviceMapper.selectById(deviceId);
        if (d == null || !d.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "设备不存在");
        }
        d.setStatus(0);
        d.setTokenHash(null); // 令牌立即失效
        deviceMapper.updateById(d);
        log.info("用户 {} 解绑设备 {}", userId, d.getDeviceSn());
    }

    @Override
    public Device requireByToken(String deviceToken) {
        if (deviceToken == null || deviceToken.isEmpty()) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED, "缺少设备令牌");
        }
        Device d = deviceMapper.selectOne(new LambdaQueryWrapper<Device>()
                .eq(Device::getTokenHash, sha256(deviceToken))
                .eq(Device::getStatus, 1)
                .last("limit 1"));
        if (d == null) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED, "设备令牌无效或已解绑");
        }
        return d;
    }

    private static String safeType(Device d) {
        return d.getDeviceType() == null ? "" : d.getDeviceType();
    }

    private static LocalDateTime parseTime(String s) {
        if (s == null || s.trim().isEmpty()) {
            return LocalDateTime.now();
        }
        try {
            return LocalDateTime.parse(s.trim().replace('T', ' '),
                    FMT);
        } catch (Exception e) {
            try {
                return LocalDateTime.parse(s.trim().replace(' ', 'T'));
            } catch (Exception ignored) {
                return LocalDateTime.now();
            }
        }
    }

    private static String sha256(String s) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] out = md.digest(s.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : out) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (Exception e) {
            throw new IllegalStateException("SHA-256 不可用", e);
        }
    }
}
