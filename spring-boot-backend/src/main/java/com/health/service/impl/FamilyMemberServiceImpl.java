package com.health.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.health.domain.entity.FamilyMember;
import com.health.domain.mapper.FamilyMemberMapper;
import com.health.exception.BusinessException;
import com.health.exception.ErrorCode;
import com.health.interfaces.dto.FamilyMemberRequest;
import com.health.interfaces.dto.FamilyMemberResponse;
import com.health.service.FamilyMemberService;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.BeanUtils;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.stream.Collectors;

/**
 * 家庭成员服务实现
 */
@Service
@RequiredArgsConstructor
public class FamilyMemberServiceImpl implements FamilyMemberService {

    private final FamilyMemberMapper familyMemberMapper;
    private static final DateTimeFormatter DATE_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd");

    @Override
    public List<FamilyMemberResponse> getList(Long userId) {
        List<FamilyMember> list = familyMemberMapper.selectList(
                new LambdaQueryWrapper<FamilyMember>()
                        .eq(FamilyMember::getUserId, userId)
                        .orderByAsc(FamilyMember::getSortOrder)
                        .orderByAsc(FamilyMember::getCreateTime)
        );
        return list.stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    @Override
    public FamilyMemberResponse getById(Long id, Long userId) {
        FamilyMember member = familyMemberMapper.selectById(id);
        if (member == null || !member.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.MEMBER_NOT_FOUND, "成员不存在");
        }
        return toResponse(member);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public FamilyMemberResponse create(Long userId, FamilyMemberRequest request) {
        FamilyMember member = new FamilyMember();
        BeanUtils.copyProperties(request, member);
        member.setUserId(userId);
        member.setRole(request.getRole() != null ? request.getRole() : "member");
        member.setSortOrder(getNextSortOrder(userId));
        familyMemberMapper.insert(member);
        return toResponse(member);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public FamilyMemberResponse update(Long id, Long userId, FamilyMemberRequest request) {
        FamilyMember member = familyMemberMapper.selectById(id);
        if (member == null || !member.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.MEMBER_NOT_FOUND, "成员不存在");
        }
        BeanUtils.copyProperties(request, member, "id");
        familyMemberMapper.updateById(member);
        return toResponse(member);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void delete(Long id, Long userId) {
        FamilyMember member = familyMemberMapper.selectById(id);
        if (member == null || !member.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.MEMBER_NOT_FOUND, "成员不存在");
        }
        familyMemberMapper.deleteById(id);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void batchDelete(List<Long> ids, Long userId) {
        if (ids == null || ids.isEmpty()) {
            return;
        }
        // 批量检查所有权
        long count = familyMemberMapper.selectCount(
                new LambdaQueryWrapper<FamilyMember>()
                        .in(FamilyMember::getId, ids)
                        .eq(FamilyMember::getUserId, userId)
        );
        if (count != ids.size()) {
            throw new BusinessException(ErrorCode.MEMBER_NOT_FOUND, "包含不存在的成员");
        }
        // 批量删除
        familyMemberMapper.delete(
                new LambdaQueryWrapper<FamilyMember>()
                        .in(FamilyMember::getId, ids)
                        .eq(FamilyMember::getUserId, userId)
        );
    }

    /**
     * 获取下一个排序序号
     */
    private Integer getNextSortOrder(Long userId) {
        // 使用分页查询代替LIMIT 1，避免SQL拼接
        Page<FamilyMember> page = familyMemberMapper.selectPage(
                new Page<>(1, 1),
                new LambdaQueryWrapper<FamilyMember>()
                        .eq(FamilyMember::getUserId, userId)
                        .orderByDesc(FamilyMember::getSortOrder)
        );
        return page.getRecords().isEmpty() ? 1 : page.getRecords().get(0).getSortOrder() + 1;
    }

    /**
     * 转换为响应对象
     */
    private FamilyMemberResponse toResponse(FamilyMember member) {
        FamilyMemberResponse response = new FamilyMemberResponse();
        BeanUtils.copyProperties(member, response);
        if (member.getBirthday() != null) {
            response.setBirthday(member.getBirthday().format(DATE_FORMATTER));
        }
        return response;
    }
}
