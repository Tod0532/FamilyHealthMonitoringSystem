package com.health.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.health.domain.entity.FamilyMember;
import com.health.domain.entity.HealthData;
import com.health.domain.entity.User;
import com.health.domain.mapper.FamilyMemberMapper;
import com.health.domain.mapper.HealthDataMapper;
import com.health.domain.mapper.UserMapper;
import com.health.exception.BusinessException;
import com.health.exception.ErrorCode;
import com.health.interfaces.dto.HealthDataRequest;
import com.health.interfaces.dto.HealthDataResponse;
import com.health.interfaces.dto.HealthStatsResponse;
import com.health.service.HealthDataService;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.BeanUtils;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

/**
 * 健康数据服务实现
 */
@Service
@RequiredArgsConstructor
public class HealthDataServiceImpl implements HealthDataService {

    private final HealthDataMapper healthDataMapper;
    private final FamilyMemberMapper familyMemberMapper;
    private final UserMapper userMapper;
    private static final DateTimeFormatter DATETIME_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
    private static final int MAX_PAGE_SIZE = 100;

    @Override
    public List<HealthDataResponse> getList(Long userId, Long memberId, String dataType,
                                             String startDate, String endDate, Integer page, Integer size) {
        // 获取用户的familyId
        Long familyId = getUserFamilyId(userId);
        if (familyId == null) {
            throw new BusinessException(ErrorCode.FAMILY_NOT_FOUND, "您还未加入家庭");
        }

        LambdaQueryWrapper<HealthData> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(HealthData::getFamilyId, familyId);

        if (memberId != null) {
            wrapper.eq(HealthData::getMemberId, memberId);
        }
        if (StringUtils.hasText(dataType)) {
            wrapper.eq(HealthData::getDataType, dataType);
        }
        if (StringUtils.hasText(startDate)) {
            try {
                LocalDateTime startDateTime = LocalDateTime.parse(startDate + " 00:00:00", DATETIME_FORMATTER);
                wrapper.ge(HealthData::getMeasureTime, startDateTime);
            } catch (Exception e) {
                throw new BusinessException(ErrorCode.INVALID_PARAM, "开始日期格式错误");
            }
        }
        if (StringUtils.hasText(endDate)) {
            try {
                LocalDateTime endDateTime = LocalDateTime.parse(endDate + " 23:59:59", DATETIME_FORMATTER);
                wrapper.le(HealthData::getMeasureTime, endDateTime);
            } catch (Exception e) {
                throw new BusinessException(ErrorCode.INVALID_PARAM, "结束日期格式错误");
            }
        }

        wrapper.orderByDesc(HealthData::getMeasureTime);

        // 使用分页查询代替SQL拼接
        int currentPage = page != null && page > 0 ? page : 1;
        int pageSize = size != null && size > 0 ? Math.min(size, MAX_PAGE_SIZE) : 20;

        Page<HealthData> pageResult = healthDataMapper.selectPage(
                new Page<>(currentPage, pageSize),
                wrapper
        );

        return pageResult.getRecords().stream()
                .map(this::toResponse)
                .toList();
    }

    @Override
    public HealthDataResponse getById(Long id, Long userId) {
        HealthData data = healthDataMapper.selectById(id);
        if (data == null) {
            throw new BusinessException(ErrorCode.DATA_NOT_FOUND, "数据不存在");
        }
        // 检查是否是同家庭成员
        Long familyId = getUserFamilyId(userId);
        if (familyId == null || !familyId.equals(data.getFamilyId())) {
            throw new BusinessException(ErrorCode.DATA_NOT_FOUND, "数据不存在");
        }
        return toResponse(data);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public HealthDataResponse create(Long userId, HealthDataRequest request) {
        // 验证成员是否存在
        if (request.getMemberId() != null) {
            validateMember(request.getMemberId(), userId);
        }

        HealthData data = new HealthData();
        BeanUtils.copyProperties(request, data);
        data.setUserId(userId);
        data.setDataSource(StringUtils.hasText(request.getDataSource()) ? request.getDataSource() : "manual");

        // 设置familyId（从成员信息中获取）
        if (request.getMemberId() != null) {
            FamilyMember member = familyMemberMapper.selectById(request.getMemberId());
            if (member != null) {
                data.setFamilyId(member.getFamilyId());
            }
        } else {
            // 如果没有指定成员，使用用户的家庭ID
            Long familyId = getUserFamilyId(userId);
            data.setFamilyId(familyId);
        }

        if (StringUtils.hasText(request.getMeasureTime())) {
            try {
                data.setMeasureTime(LocalDateTime.parse(request.getMeasureTime(), DATETIME_FORMATTER));
            } catch (Exception e) {
                throw new BusinessException(ErrorCode.INVALID_PARAM, "测量时间格式错误");
            }
        } else {
            data.setMeasureTime(LocalDateTime.now());
        }

        healthDataMapper.insert(data);

        // 检查预警规则并创建预警记录
        // TODO: 实现预警检查逻辑

        return toResponse(data);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public List<HealthDataResponse> batchCreate(Long userId, List<HealthDataRequest> requests) {
        List<HealthDataResponse> results = new ArrayList<>();
        for (HealthDataRequest request : requests) {
            results.add(create(userId, request));
        }
        return results;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public HealthDataResponse update(Long id, Long userId, HealthDataRequest request) {
        HealthData data = healthDataMapper.selectById(id);
        if (data == null) {
            throw new BusinessException(ErrorCode.DATA_NOT_FOUND, "数据不存在");
        }
        // 检查是否是同家庭成员
        Long familyId = getUserFamilyId(userId);
        if (familyId == null || !familyId.equals(data.getFamilyId())) {
            throw new BusinessException(ErrorCode.DATA_NOT_FOUND, "数据不存在");
        }

        if (request.getMemberId() != null && !request.getMemberId().equals(data.getMemberId())) {
            validateMember(request.getMemberId(), userId);
        }

        BeanUtils.copyProperties(request, data, "id", "userId", "measureTime");
        if (StringUtils.hasText(request.getMeasureTime())) {
            try {
                data.setMeasureTime(LocalDateTime.parse(request.getMeasureTime(), DATETIME_FORMATTER));
            } catch (Exception e) {
                throw new BusinessException(ErrorCode.INVALID_PARAM, "测量时间格式错误");
            }
        }

        healthDataMapper.updateById(data);
        return toResponse(data);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void delete(Long id, Long userId) {
        HealthData data = healthDataMapper.selectById(id);
        if (data == null) {
            throw new BusinessException(ErrorCode.DATA_NOT_FOUND, "数据不存在");
        }
        // 检查是否是同家庭成员
        Long familyId = getUserFamilyId(userId);
        if (familyId == null || !familyId.equals(data.getFamilyId())) {
            throw new BusinessException(ErrorCode.DATA_NOT_FOUND, "数据不存在");
        }
        healthDataMapper.deleteById(id);
    }

    @Override
    public HealthStatsResponse getStats(Long userId, Long memberId, String dataType, String startDate, String endDate) {
        List<HealthDataResponse> dataList = getList(userId, memberId, dataType, startDate, endDate, null, null);

        HealthStatsResponse stats = new HealthStatsResponse();
        stats.setTotalRecords((long) dataList.size());

        if (dataList.isEmpty()) {
            return stats;
        }

        // 计算平均值、最大值、最小值
        List<Double> values = dataList.stream()
                .filter(d -> d.getValue1() != null)
                .map(d -> d.getValue1().doubleValue())
                .collect(Collectors.toList());

        if (!values.isEmpty()) {
            stats.setAverage(values.stream().mapToDouble(Double::doubleValue).average().orElse(0));
            stats.setMaximum(values.stream().mapToDouble(Double::doubleValue).max().orElse(0));
            stats.setMinimum(values.stream().mapToDouble(Double::doubleValue).min().orElse(0));
        }

        // 时间范围
        stats.setEarliestTime(dataList.get(dataList.size() - 1).getMeasureTime().toString());
        stats.setLatestTime(dataList.get(0).getMeasureTime().toString());

        // 趋势数据
        stats.setTrendData(getTrend(userId, memberId, dataType));

        return stats;
    }

    @Override
    public List<HealthStatsResponse.TrendData> getTrend(Long userId, Long memberId, String dataType) {
        // 获取用户的familyId
        Long familyId = getUserFamilyId(userId);
        if (familyId == null) {
            return new ArrayList<>();
        }

        // 获取最近7天的数据
        LocalDateTime endTime = LocalDateTime.now();
        LocalDateTime startTime = endTime.minusDays(7);

        List<HealthData> list = healthDataMapper.selectList(
                new LambdaQueryWrapper<HealthData>()
                        .eq(HealthData::getFamilyId, familyId)
                        .eq(memberId != null, HealthData::getMemberId, memberId)
                        .eq(dataType != null, HealthData::getDataType, dataType)
                        .ge(HealthData::getMeasureTime, startTime)
                        .le(HealthData::getMeasureTime, endTime)
                        .orderByAsc(HealthData::getMeasureTime)
        );

        // 按日期分组计算平均值
        Map<String, List<Double>> groupedData = new LinkedHashMap<>();
        for (HealthData data : list) {
            String date = data.getMeasureTime().format(DateTimeFormatter.ofPattern("yyyy-MM-dd"));
            if (data.getValue1() != null) {
                groupedData.computeIfAbsent(date, k -> new ArrayList<>()).add(data.getValue1().doubleValue());
            }
        }

        List<HealthStatsResponse.TrendData> trendData = new ArrayList<>();
        for (Map.Entry<String, List<Double>> entry : groupedData.entrySet()) {
            HealthStatsResponse.TrendData data = new HealthStatsResponse.TrendData();
            data.setDate(entry.getKey());
            double avg = entry.getValue().stream().mapToDouble(Double::doubleValue).average().orElse(0);
            data.setValue(Math.round(avg * 10.0) / 10.0); // 保留一位小数
            trendData.add(data);
        }

        return trendData;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void clearUserData(Long userId) {
        healthDataMapper.delete(
                new LambdaQueryWrapper<HealthData>()
                        .eq(HealthData::getUserId, userId)
        );
    }

    /**
     * 获取用户的家庭ID
     */
    private Long getUserFamilyId(Long userId) {
        User user = userMapper.selectById(userId);
        return user != null ? user.getFamilyId() : null;
    }

    /**
     * 验证成员是否存在（家庭成员可以互相记录健康数据）
     */
    private void validateMember(Long memberId, Long userId) {
        FamilyMember member = familyMemberMapper.selectById(memberId);
        if (member == null) {
            throw new BusinessException(ErrorCode.MEMBER_NOT_FOUND, "成员不存在");
        }
        // 检查是否在同一家庭
        Long userFamilyId = getUserFamilyId(userId);
        if (userFamilyId == null || !userFamilyId.equals(member.getFamilyId())) {
            throw new BusinessException(ErrorCode.MEMBER_NOT_FOUND, "成员不存在或不在同一家庭");
        }
    }

    /**
     * 转换为响应对象
     */
    private HealthDataResponse toResponse(HealthData data) {
        HealthDataResponse response = new HealthDataResponse();
        BeanUtils.copyProperties(data, response);

        // 获取成员名称
        if (data.getMemberId() != null) {
            FamilyMember member = familyMemberMapper.selectById(data.getMemberId());
            if (member != null) {
                response.setMemberName(member.getName());
            }
        }

        // 设置类型标签
        response.setDataTypeLabel(getDataTypeLabel(data.getDataType()));

        // 设置显示值
        response.setDisplayValue(formatDisplayValue(data));

        return response;
    }

    /**
     * 获取数据类型标签
     */
    private String getDataTypeLabel(String dataType) {
        Map<String, String> labels = Map.of(
                "blood_pressure", "血压",
                "heart_rate", "心率",
                "blood_sugar", "血糖",
                "temperature", "体温",
                "weight", "体重",
                "height", "身高",
                "steps", "步数",
                "sleep", "睡眠"
        );
        return labels.getOrDefault(dataType, dataType);
    }

    /**
     * 格式化显示值
     */
    private String formatDisplayValue(HealthData data) {
        String unit = data.getUnit() != null ? data.getUnit() : "";
        switch (data.getDataType()) {
            case "blood_pressure":
                if (data.getValue1() != null && data.getValue2() != null) {
                    return data.getValue1().intValue() + "/" + data.getValue2().intValue() + " " + unit;
                }
                return "--/-- " + unit;
            case "sleep":
                if (data.getValue1() != null) {
                    return data.getValue1().intValue() + " " + unit;
                }
                return "-- " + unit;
            default:
                if (data.getValue1() != null) {
                    return data.getValue1().setScale(1, RoundingMode.HALF_UP).toString() + " " + unit;
                }
                return "-- " + unit;
        }
    }
}
