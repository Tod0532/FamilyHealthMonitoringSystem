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
import org.springframework.beans.factory.annotation.Autowired;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.math.BigDecimal;
import java.time.Duration;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
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

    /** 预警评估器：设备上报的数据同样要过规则判定 */
    @Autowired
    private AlertEvaluator alertEvaluator;

    private static final SecureRandom RANDOM = new SecureRandom();
    private static final int BIND_CODE_MINUTES = 10;
    private static final DateTimeFormatter FMT =
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    /**
     * 落库节流阈值（与固件 ESP32_HR_BRIDGE 的 HR_CHANGE_THRESHOLD / 上报周期保持一致）
     *
     * 板子 5 秒一报 = 一天约 1.7 万条，全量入库会把 health_data 刷爆，
     * 而历史趋势并不需要 5 秒粒度。因此：
     *   变化 ≥ HR_STORE_DELTA_BPM 或 距上次入库 > HR_STORE_INTERVAL_SECONDS 才写库，
     *   其余仅更新下面的实时缓存（不影响 App 实时监控的读数）。
     */
    private static final int HR_STORE_DELTA_BPM = 3;
    private static final long HR_STORE_INTERVAL_SECONDS = 60;

    /**
     * 实时值缓存：设备 id → 最近一次上报（**不落库**）
     *
     * 为什么不直接查库取"最新一条"：落库被节流后，库里最新记录最多可能滞后
     * 60 秒，实时监控页会一直显示旧值。所以每次上报都刷新这里，
     * /api/device/latest 优先取缓存、缓存不可用再回退查库。
     *
     * 值为不可变对象（每次上报新建实例后整体替换），因此并发读无需加锁。
     * 进程重启即清空 —— 这是实时值，允许丢失（库里还有节流后的历史）。
     */
    private static final Map<Long, Realtime> REALTIME = new ConcurrentHashMap<>();

    /** 单次上报的实时快照（不可变） */
    private static final class Realtime {
        final BigDecimal heartRate;
        final LocalDateTime measureTime;
        /** 上一次真正写库的数值与时刻，用于节流判定 */
        final BigDecimal storedValue;
        final LocalDateTime storedAt;

        Realtime(BigDecimal heartRate, LocalDateTime measureTime,
                 BigDecimal storedValue, LocalDateTime storedAt) {
            this.heartRate = heartRate;
            this.measureTime = measureTime;
            this.storedValue = storedValue;
            this.storedAt = storedAt;
        }
    }

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
        final LocalDateTime now = LocalDateTime.now();
        final LocalDateTime measureTime = parseTime(req.getMeasureTime());
        final boolean heartRate = "heart_rate".equals(req.getDataType());

        // ── 库中已有的实时值快照（仅心率走节流；其它类型数据量小，照旧全量入库）──
        Realtime prev = heartRate ? REALTIME.get(d.getId()) : null;
        if (heartRate && prev == null) {
            // 进程刚重启：以库里最新一条为节流基准，避免重启后又连写一串
            HealthData lastStored = latestStoredHeartRate(d.getMemberId());
            if (lastStored != null) {
                prev = new Realtime(lastStored.getValue1(),
                        lastStored.getMeasureTime(), lastStored.getValue1(),
                        lastStored.getMeasureTime());
            }
        }

        final boolean shouldStore = !heartRate || shouldStoreHeartRate(prev, req.getValue1(), now);

        if (shouldStore) {
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
            data.setMeasureTime(measureTime);
            data.setCreateTime(now);
            data.setUpdateTime(now);
            data.setDeleted(0);
            healthDataMapper.insert(data);
        }

        // 实时值：**每次上报都刷新**，实时监控页据此拿到秒级读数
        if (heartRate) {
            final BigDecimal storedValue =
                    shouldStore ? req.getValue1() : (prev == null ? null : prev.storedValue);
            final LocalDateTime storedAt =
                    shouldStore ? measureTime : (prev == null ? null : prev.storedAt);
            REALTIME.put(d.getId(), new Realtime(req.getValue1(), measureTime,
                    storedValue, storedAt));
        }

        // 走同样的预警判定：设备上报此前直接插库、绕过了规则评估，
        // 导致心率越界不会产生预警记录（实时监控里这是必须补的）
        alertEvaluator.evaluate(d.getUserId(), d.getMemberId(),
                req.getDataType(), req.getValue1());

        d.setLastSeen(now);
        deviceMapper.updateById(d);
        log.info("设备 {} 上报 {}={}（成员 {}，{}）",
                d.getDeviceSn(), req.getDataType(), req.getValue1(), d.getMemberId(),
                shouldStore ? "已入库" : "仅更新实时值（节流）");
    }

    /**
     * 心率落库节流判定：首次入库、变化 ≥3bpm、或距上次入库 >60 秒才写库。
     * 中间那些读数只更新实时缓存，不进 health_data。
     */
    private boolean shouldStoreHeartRate(Realtime prev, BigDecimal value, LocalDateTime now) {
        if (prev == null || prev.storedValue == null || prev.storedAt == null) {
            return true; // 首次上报
        }
        if (value == null) {
            return true;
        }
        final BigDecimal last = prev.storedValue;
        if (last.subtract(value).abs().intValue() >= HR_STORE_DELTA_BPM) {
            return true;
        }
        final long elapsed = Duration.between(prev.storedAt, now).getSeconds();
        // elapsed < 0 说明设备时钟比服务端快（measureTime 落在将来）。
        // 此时不能按"距上次入库 >60 秒"判断，否则时间差永远为负、永远不入库，
        // 等于把这条链路静默掐死。按间隔到了处理。
        return elapsed > HR_STORE_INTERVAL_SECONDS || elapsed < 0;
    }

    /** 库里该成员最近一条"设备来源"的心率记录（用于重启后的节流基准） */
    private HealthData latestStoredHeartRate(Long memberId) {
        return healthDataMapper.selectOne(new LambdaQueryWrapper<HealthData>()
                .eq(HealthData::getMemberId, memberId)
                .eq(HealthData::getDataType, "heart_rate")
                .eq(HealthData::getDataSource, "device")
                .orderByDesc(HealthData::getMeasureTime)
                .orderByDesc(HealthData::getId)
                .last("limit 1"));
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

            // 实时值优先级：
            //   1) 实时缓存（每次上报都刷新，落库节流也不影响它）
            //   2) 库里最近一条"设备来源"的心率记录
            // 缓存的过程内重启后为空，自动回退到库，不会显示成"从未上报"。
            BigDecimal value = null;
            LocalDateTime measuredAt = null;
            final Realtime rt = REALTIME.get(d.getId());
            if (rt != null && rt.measureTime != null) {
                value = rt.heartRate;
                measuredAt = rt.measureTime;
            } else {
                HealthData latest = latestStoredHeartRate(d.getMemberId());
                if (latest != null) {
                    value = latest.getValue1();
                    measuredAt = latest.getMeasureTime();
                }
            }

            if (value != null) {
                vo.setHeartRate(value);
                if (measuredAt != null) {
                    vo.setMeasureTime(measuredAt.format(FMT));
                    final long age = java.time.Duration.between(measuredAt, now).getSeconds();
                    vo.setAgeSeconds(Math.max(0, age));
                    // 超过 20 秒没有新值即视为陈旧：宁可显示"已断开"，
                    // 也不要把几分钟前的旧读数当成实时值（会误判健康状况）。
                    // 板子 5 秒一报，20 秒 ≈ 连丢 4 包，足够说明链路有问题。
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
        REALTIME.remove(deviceId); // 顺带清掉实时值，避免解绑后还显示旧读数
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
