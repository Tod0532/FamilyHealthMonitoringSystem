package com.health.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.health.domain.entity.AlertRecord;
import com.health.domain.entity.FamilyMember;
import com.health.domain.mapper.AlertRecordMapper;
import com.health.domain.mapper.FamilyMemberMapper;
import com.health.exception.BusinessException;
import com.health.exception.ErrorCode;
import com.health.interfaces.dto.AlertRecordResponse;
import com.health.service.AlertRecordService;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.BeanUtils;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 预警记录服务实现
 */
@Service
@RequiredArgsConstructor
public class AlertRecordServiceImpl implements AlertRecordService {

    private final AlertRecordMapper alertRecordMapper;
    private final FamilyMemberMapper familyMemberMapper;
    private static final int MAX_PAGE_SIZE = 100;

    @Override
    public List<AlertRecordResponse> getList(Long userId, Long memberId, String status, Integer page, Integer size) {
        LambdaQueryWrapper<AlertRecord> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(AlertRecord::getUserId, userId);

        if (memberId != null) {
            wrapper.eq(AlertRecord::getMemberId, memberId);
        }
        if (StringUtils.hasText(status)) {
            wrapper.eq(AlertRecord::getStatus, status);
        }

        wrapper.orderByDesc(AlertRecord::getCreateTime);

        // 使用分页查询代替SQL拼接
        int currentPage = page != null && page > 0 ? page : 1;
        int pageSize = size != null && size > 0 ? Math.min(size, MAX_PAGE_SIZE) : 20;

        Page<AlertRecord> pageResult = alertRecordMapper.selectPage(
                new Page<>(currentPage, pageSize),
                wrapper
        );

        return pageResult.getRecords().stream()
                .map(this::toResponse)
                .toList();
    }

    @Override
    public Long getUnreadCount(Long userId) {
        return alertRecordMapper.selectCount(
                new LambdaQueryWrapper<AlertRecord>()
                        .eq(AlertRecord::getUserId, userId)
                        .eq(AlertRecord::getStatus, "unread")
        );
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void markAsRead(Long id, Long userId) {
        AlertRecord record = alertRecordMapper.selectById(id);
        if (record == null || !record.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "记录不存在");
        }
        if ("unread".equals(record.getStatus())) {
            record.setStatus("read");
            alertRecordMapper.updateById(record);
        }
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void markAllAsRead(Long userId) {
        // 使用批量更新提高性能
        List<AlertRecord> unreadRecords = alertRecordMapper.selectList(
                new LambdaQueryWrapper<AlertRecord>()
                        .eq(AlertRecord::getUserId, userId)
                        .eq(AlertRecord::getStatus, "unread")
        );
        for (AlertRecord record : unreadRecords) {
            record.setStatus("read");
            alertRecordMapper.updateById(record);
        }
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void handle(Long id, Long userId) {
        AlertRecord record = alertRecordMapper.selectById(id);
        if (record == null || !record.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "记录不存在");
        }
        record.setStatus("handled");
        record.setHandleTime(LocalDateTime.now());
        alertRecordMapper.updateById(record);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void delete(Long id, Long userId) {
        AlertRecord record = alertRecordMapper.selectById(id);
        if (record == null || !record.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "记录不存在");
        }
        alertRecordMapper.deleteById(id);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void clearUserData(Long userId) {
        alertRecordMapper.delete(
                new LambdaQueryWrapper<AlertRecord>()
                        .eq(AlertRecord::getUserId, userId)
        );
    }

    /**
     * 转换为响应对象
     */
    private AlertRecordResponse toResponse(AlertRecord record) {
        AlertRecordResponse response = new AlertRecordResponse();
        BeanUtils.copyProperties(record, response);

        // 获取成员名称
        if (record.getMemberId() != null) {
            FamilyMember member = familyMemberMapper.selectById(record.getMemberId());
            if (member != null) {
                response.setMemberName(member.getName());
            }
        }

        response.setAlertTypeLabel(getAlertTypeLabel(record.getAlertType()));
        response.setAlertLevelLabel(getAlertLevelLabel(record.getAlertLevel()));
        response.setStatusLabel(getStatusLabel(record.getStatus()));

        return response;
    }

    private String getAlertTypeLabel(String alertType) {
        return switch (alertType) {
            case "blood_pressure" -> "血压";
            case "heart_rate" -> "心率";
            case "blood_sugar" -> "血糖";
            case "temperature" -> "体温";
            case "weight" -> "体重";
            default -> alertType;
        };
    }

    private String getAlertLevelLabel(String alertLevel) {
        return switch (alertLevel) {
            case "info" -> "提示";
            case "warning" -> "警告";
            case "danger" -> "危险";
            default -> alertLevel;
        };
    }

    private String getStatusLabel(String status) {
        return switch (status) {
            case "unread" -> "未读";
            case "read" -> "已读";
            case "handled" -> "已处理";
            default -> status;
        };
    }
}
