package com.health.service.impl;

import com.baomidou.mybatisplus.core.conditions.Wrapper;
import com.health.domain.entity.Device;
import com.health.domain.entity.FamilyMember;
import com.health.domain.entity.HealthData;
import com.health.domain.mapper.DeviceMapper;
import com.health.domain.mapper.FamilyMemberMapper;
import com.health.domain.mapper.HealthDataMapper;
import com.health.interfaces.dto.DeviceDtos;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.test.util.ReflectionTestUtils;

import java.lang.reflect.Field;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * 设备上报的**落库节流**与**实时值缓存**测试
 *
 * 背景：板子改成 5 秒一报（一天约 1.7 万条），必须只把有意义的点写进
 * health_data（变化 ≥3bpm 或距上次入库 >60 秒），其余只更新内存实时值。
 * 这里把边界钉死，避免以后有人"顺手"改回每报必插：
 *   · 首次上报            → 必入库（否则库里没有起点）
 *   · 变化 <3bpm 且 <60s  → 不入库，但实时值必须刷新（实时监控页靠它）
 *   · 变化 ≥3bpm / >60s   → 入库
 *   · /api/device/latest  → 优先返回实时缓存，而不是被节流过的旧记录
 *
 * 注意：实时值缓存 DeviceServiceImpl.REALTIME 是静态的、跨用例共享，
 * 所以每个用例用**不同的 deviceId**，避免互相污染。
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class DeviceReportThrottleTest {

    private static final String TOKEN = "test-device-token";
    private static final DateTimeFormatter FMT =
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    @Mock
    private DeviceMapper deviceMapper;
    @Mock
    private FamilyMemberMapper familyMemberMapper;
    @Mock
    private HealthDataMapper healthDataMapper;
    @Mock
    private AlertEvaluator alertEvaluator;

    private DeviceServiceImpl service;

    /**
     * 注意：AlertEvaluator 在 DeviceServiceImpl 里是**字段级 @Autowired**（不在构造器里），
     * 所以 @InjectMocks 不会注入它 —— 实测会 NPE。这里显式补上。
     */
    @BeforeEach
    void setUp() {
        service = new DeviceServiceImpl(deviceMapper, familyMemberMapper, healthDataMapper);
        ReflectionTestUtils.setField(service, "alertEvaluator", alertEvaluator);
    }

    // ───────────────────────── 测试脚手架 ─────────────────────────

    /** 造一台已绑定、令牌有效的设备 */
    private Device boundDevice(long deviceId, long memberId) {
        Device d = new Device();
        d.setId(deviceId);
        d.setUserId(1L);
        d.setMemberId(memberId);
        d.setDeviceSn("HR-TEST-" + deviceId);
        d.setDeviceName("测试手环桥");
        d.setDeviceType("esp32_hr_bridge");
        d.setStatus(1);
        d.setLastSeen(LocalDateTime.now());
        when(deviceMapper.selectOne(any(Wrapper.class))).thenReturn(d);
        return d;
    }

    /** report() 需要成员来取 familyId（漏写 family_id 会导致 App 看不到数据） */
    private void stubMember(long memberId) {
        FamilyMember m = new FamilyMember();
        m.setId(memberId);
        m.setFamilyId(100L);
        m.setName("测试成员");
        when(familyMemberMapper.selectById(memberId)).thenReturn(m);
    }

    /** 库里还没有任何心率记录 */
    private void stubNoHistory() {
        when(healthDataMapper.selectOne(any(Wrapper.class))).thenReturn(null);
    }

    private void report(int bpm, LocalDateTime measureTime) {
        DeviceDtos.DeviceReportRequest req = new DeviceDtos.DeviceReportRequest();
        req.setDataType("heart_rate");
        req.setValue1(BigDecimal.valueOf(bpm));
        req.setUnit("bpm");
        req.setMeasureTime(measureTime.format(FMT));
        service.report(TOKEN, req);
    }

    private void report(int bpm) {
        report(bpm, LocalDateTime.now());
    }

    /** 直接读静态实时缓存（比走 listLatest 更贴近被测点） */
    @SuppressWarnings("unchecked")
    private BigDecimal realtimeHeartRate(long deviceId) {
        try {
            Field f = DeviceServiceImpl.class.getDeclaredField("REALTIME");
            f.setAccessible(true);
            final Map<Long, Object> map = (Map<Long, Object>) f.get(null);
            final Object rt = map.get(deviceId);
            if (rt == null) {
                return null;
            }
            Field vf = rt.getClass().getDeclaredField("heartRate");
            vf.setAccessible(true);
            return (BigDecimal) vf.get(rt);
        } catch (ReflectiveOperationException e) {
            throw new IllegalStateException("读取实时缓存失败", e);
        }
    }

    private static void assertBpm(int expected, BigDecimal actual, String msg) {
        assertNotNull(actual, msg);
        assertEquals(0, BigDecimal.valueOf(expected).compareTo(actual), msg);
    }

    // ───────────────────────── 用例 ─────────────────────────

    @Test
    @DisplayName("首次上报：必须入库，实时值也要更新")
    void firstReportAlwaysStored() {
        boundDevice(9001L, 101L);
        stubMember(101L);
        stubNoHistory();

        report(75);

        verify(healthDataMapper, times(1)).insert(any(HealthData.class));
        assertBpm(75, realtimeHeartRate(9001L), "实时值应为 75");
    }

    @Test
    @DisplayName("5 秒后微变（<3bpm）：不入库，但实时值要刷新——否则实时监控页卡在旧值")
    void smallChangeNotStoredButRealtimeRefreshed() {
        boundDevice(9002L, 102L);
        stubMember(102L);
        stubNoHistory();

        report(75);   // 首次 → 入库
        report(77);   // +2bpm，未达阈值 → 只更新实时值

        verify(healthDataMapper, times(1)).insert(any(HealthData.class));
        assertBpm(77, realtimeHeartRate(9002L), "实时值应已刷新到 77");
    }

    @Test
    @DisplayName("变化 ≥3bpm：立即入库")
    void deltaAtThresholdStored() {
        boundDevice(9003L, 103L);
        stubMember(103L);
        stubNoHistory();

        report(75);
        report(78);   // 正好 +3bpm

        verify(healthDataMapper, times(2)).insert(any(HealthData.class));
        assertBpm(78, realtimeHeartRate(9003L), "实时值应为 78");
    }

    @Test
    @DisplayName("数值没变但距上次入库已过 60 秒：再入库一次，保证趋势图时间轴稳定")
    void unchangedButIntervalElapsedStored() {
        boundDevice(9004L, 104L);
        stubMember(104L);
        stubNoHistory();

        report(75, LocalDateTime.now().minusSeconds(61));
        report(75);   // 距上次入库 >60 秒

        verify(healthDataMapper, times(2)).insert(any(HealthData.class));
    }

    @Test
    @DisplayName("listLatest 优先返回实时缓存，而不是库里那条被节流过的旧记录")
    void latestPrefersRealtimeCacheOverThrottledRow() {
        final long deviceId = 9005L;
        final long memberId = 105L;
        final Device device = boundDevice(deviceId, memberId);
        stubMember(memberId);

        // 库里那条最新记录还是 50 秒前写入的 75
        HealthData stored = new HealthData();
        stored.setId(1L);
        stored.setMemberId(memberId);
        stored.setValue1(BigDecimal.valueOf(75));
        stored.setMeasureTime(LocalDateTime.now().minusSeconds(50));
        when(healthDataMapper.selectOne(any(Wrapper.class))).thenReturn(stored);
        when(deviceMapper.selectList(any(Wrapper.class))).thenReturn(List.of(device));

        report(75, LocalDateTime.now().minusSeconds(50)); // 首次 → 入库
        report(90);                                       // +15bpm → 入库，同时刷新缓存

        List<DeviceDtos.DeviceLatestVO> out = service.listLatest(1L);
        assertEquals(1, out.size());
        DeviceDtos.DeviceLatestVO vo = out.get(0);
        assertBpm(90, vo.getHeartRate(), "实时值应取缓存里的 90");
        assertFalse(Boolean.TRUE.equals(vo.getStale()), "刚上报过，不应标记为陈旧");
        assertNotNull(vo.getAgeSeconds());
    }
}
