package com.health.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.health.domain.entity.FamilyMember;
import com.health.domain.entity.User;
import com.health.domain.mapper.FamilyMapper;
import com.health.domain.mapper.FamilyMemberMapper;
import com.health.domain.mapper.UserMapper;
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
    private final UserMapper userMapper;
    private final FamilyMapper familyMapper;
    private static final DateTimeFormatter DATE_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd");

    @Override
    public List<FamilyMemberResponse> getList(Long userId) {
        // 获取用户的familyId
        Long familyId = getUserFamilyId(userId);
        if (familyId == null) {
            return List.of();
        }

        List<FamilyMember> list = familyMemberMapper.selectList(
                new LambdaQueryWrapper<FamilyMember>()
                        .eq(FamilyMember::getFamilyId, familyId)
                        .orderByAsc(FamilyMember::getSortOrder)
                        .orderByAsc(FamilyMember::getCreateTime)
        );
        return list.stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    /**
     * 获取用户的家庭ID
     */
    private Long getUserFamilyId(Long userId) {
        User user = userMapper.selectById(userId);
        return user != null ? user.getFamilyId() : null;
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

        // 必须写入 family_id，否则新成员不属于任何家庭。
        // 「家庭成员」列表（/api/family/members）按 family_id 过滤，会看不到该成员，
        // 家庭 memberCount 也不计；而按用户维度查询（/api/members）又能看到，
        // 于是出现「成员存在但不属于任何家庭」的错乱。
        // 线上实测：POST /api/members 返回 200 创建成功，
        // 但家庭成员列表与 memberCount 均无变化（DB 里 family_id 为 NULL）。
        User creator = userMapper.selectById(userId);
        Long familyId = creator != null ? creator.getFamilyId() : null;
        member.setFamilyId(familyId);

        familyMemberMapper.insert(member);

        // 成员数按实际行数重算，避免 family.member_count 与实际不一致
        recalcMemberCount(familyId);

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
        Long familyId = member.getFamilyId();
        familyMemberMapper.deleteById(id);
        recalcMemberCount(familyId);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void batchDelete(List<Long> ids, Long userId) {
        if (ids == null || ids.isEmpty()) {
            return;
        }
        // 批量检查所有权
        List<FamilyMember> rows = familyMemberMapper.selectList(
                new LambdaQueryWrapper<FamilyMember>()
                        .in(FamilyMember::getId, ids)
                        .eq(FamilyMember::getUserId, userId)
        );
        if (rows.size() != ids.size()) {
            throw new BusinessException(ErrorCode.MEMBER_NOT_FOUND, "包含不存在的成员");
        }
        // 批量删除
        familyMemberMapper.delete(
                new LambdaQueryWrapper<FamilyMember>()
                        .in(FamilyMember::getId, ids)
                        .eq(FamilyMember::getUserId, userId)
        );
        // 涉及的家庭成员数按实际行数重算
        rows.stream()
                .map(FamilyMember::getFamilyId)
                .filter(java.util.Objects::nonNull)
                .distinct()
                .forEach(this::recalcMemberCount);
    }

    /**
     * 按 family_member 实际行数重算并写回 family.member_count。
     *
     * <p>与 FamilyServiceImpl 中同名方法同一套逻辑：member_count 以实际行数为
     * 唯一真相来源，避免手工加减导致的长期漂移。</p>
     */
    private void recalcMemberCount(Long familyId) {
        if (familyId == null) {
            return;
        }
        Long actual = familyMemberMapper.selectCount(
                new LambdaQueryWrapper<FamilyMember>().eq(FamilyMember::getFamilyId, familyId));
        com.health.domain.entity.Family family = familyMapper.selectById(familyId);
        if (family == null) {
            return;
        }
        int count = actual == null ? 0 : actual.intValue();
        if (family.getMemberCount() == null || family.getMemberCount() != count) {
            family.setMemberCount(count);
            family.setUpdateTime(java.time.LocalDateTime.now());
            familyMapper.updateById(family);
        }
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
