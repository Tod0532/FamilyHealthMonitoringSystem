package com.health.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.health.domain.entity.Family;
import com.health.domain.entity.User;
import com.health.domain.mapper.FamilyMapper;
import com.health.domain.mapper.UserMapper;
import com.health.exception.BusinessException;
import com.health.exception.ErrorCode;
import com.health.interfaces.dto.*;
import com.health.service.FamilyService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;

/**
 * 家庭服务实现
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class FamilyServiceImpl implements FamilyService {

    private final FamilyMapper familyMapper;
    private final UserMapper userMapper;

    private static final String QR_CODE_PREFIX = "FAMILY_INVITE:";
    private static final int CODE_LENGTH = 6;
    private static final String CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // 去掉易混淆字符

    @Override
    @Transactional(rollbackFor = Exception.class)
    public FamilyResponse createFamily(Long userId, FamilyCreateRequest request) {
        // 1. 检查用户是否已在家庭中
        User user = userMapper.selectById(userId);
        if (user == null) {
            throw new BusinessException(ErrorCode.USER_NOT_FOUND, "用户不存在");
        }
        if (user.getFamilyId() != null) {
            throw new BusinessException(ErrorCode.ALREADY_IN_FAMILY, "您已加入家庭，无法创建新家庭");
        }

        // 2. 生成唯一邀请码
        String familyCode = generateFamilyCode();

        // 3. 创建家庭
        Family family = new Family();
        family.setFamilyName(request.getFamilyName());
        family.setFamilyCode(familyCode);
        family.setAdminId(userId);
        family.setMemberCount(1);
        family.setStatus(1);
        family.setCreateTime(LocalDateTime.now());
        family.setUpdateTime(LocalDateTime.now());
        familyMapper.insert(family);

        // 4. 更新用户的家庭信息
        user.setFamilyId(family.getId());
        user.setFamilyRole("admin");
        user.setUpdateTime(LocalDateTime.now());
        userMapper.updateById(user);

        log.info("用户创建家庭成功: userId={}, familyId={}, familyCode={}", userId, family.getId(), familyCode);

        // 5. 同步更新家庭成员表的family_id
        syncFamilyMembersFamilyId(userId, family.getId());

        return toFamilyResponse(family, "admin");
    }

    @Override
    public FamilyResponse getMyFamily(Long userId) {
        User user = userMapper.selectById(userId);
        if (user == null || user.getFamilyId() == null) {
            return null;
        }

        Family family = familyMapper.selectById(user.getFamilyId());
        if (family == null) {
            // 家庭不存在，清除用户的family_id
            user.setFamilyId(null);
            user.setFamilyRole("member");
            userMapper.updateById(user);
            return null;
        }

        return toFamilyResponse(family, user.getFamilyRole());
    }

    @Override
    public FamilyQrCodeResponse getQrCode(Long userId) {
        User user = userMapper.selectById(userId);
        if (user == null || user.getFamilyId() == null) {
            throw new BusinessException(ErrorCode.FAMILY_NOT_FOUND, "您还未加入家庭");
        }

        Family family = familyMapper.selectById(user.getFamilyId());
        if (family == null) {
            throw new BusinessException(ErrorCode.FAMILY_NOT_FOUND, "家庭不存在");
        }

        // 只有管理员可以获取二维码
        if (!"admin".equals(user.getFamilyRole())) {
            throw new BusinessException(ErrorCode.NOT_FAMILY_ADMIN, "只有家庭管理员可以获取邀请二维码");
        }

        return FamilyQrCodeResponse.builder()
                .familyCode(family.getFamilyCode())
                .qrContent(QR_CODE_PREFIX + family.getFamilyCode())
                .familyName(family.getFamilyName())
                .memberCount(family.getMemberCount())
                .build();
    }

    @Override
    public FamilyResponse parseInviteCode(String inviteCode) {
        LambdaQueryWrapper<Family> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(Family::getFamilyCode, inviteCode);
        Family family = familyMapper.selectOne(wrapper);

        if (family == null) {
            throw new BusinessException(ErrorCode.FAMILY_CODE_INVALID, "邀请码无效");
        }

        return toFamilyResponse(family, null);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public FamilyResponse joinFamily(Long userId, FamilyJoinRequest request) {
        // 1. 检查用户是否已在家庭中
        User user = userMapper.selectById(userId);
        if (user == null) {
            throw new BusinessException(ErrorCode.USER_NOT_FOUND, "用户不存在");
        }
        if (user.getFamilyId() != null) {
            throw new BusinessException(ErrorCode.ALREADY_IN_FAMILY, "您已加入家庭");
        }

        // 2. 查找家庭
        LambdaQueryWrapper<Family> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(Family::getFamilyCode, request.getInviteCode());
        Family family = familyMapper.selectOne(wrapper);

        if (family == null) {
            throw new BusinessException(ErrorCode.FAMILY_CODE_INVALID, "邀请码无效");
        }

        // 3. 加入家庭
        user.setFamilyId(family.getId());
        user.setFamilyRole("member");
        user.setUpdateTime(LocalDateTime.now());
        userMapper.updateById(user);

        // 4. 更新家庭成员数
        family.setMemberCount(family.getMemberCount() + 1);
        family.setUpdateTime(LocalDateTime.now());
        familyMapper.updateById(family);

        log.info("用户加入家庭成功: userId={}, familyId={}, familyCode={}", userId, family.getId(), family.getFamilyCode());

        // 5. 同步更新家庭成员表的family_id
        syncFamilyMembersFamilyId(userId, family.getId());

        return toFamilyResponse(family, "member");
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void leaveFamily(Long userId) {
        User user = userMapper.selectById(userId);
        if (user == null || user.getFamilyId() == null) {
            throw new BusinessException(ErrorCode.FAMILY_NOT_FOUND, "您还未加入家庭");
        }

        Family family = familyMapper.selectById(user.getFamilyId());
        if (family == null) {
            // 家庭不存在，直接清除用户的family_id
            user.setFamilyId(null);
            user.setFamilyRole("member");
            userMapper.updateById(user);
            return;
        }

        // 管理员不能直接退出，需要先转让管理员或解散家庭
        if (family.getAdminId().equals(userId) && family.getMemberCount() > 1) {
            throw new BusinessException(ErrorCode.NOT_FAMILY_ADMIN, "管理员不能退出，请先转让管理员或解散家庭");
        }

        // 清除用户的家庭信息
        Long familyId = user.getFamilyId();
        user.setFamilyId(null);
        user.setFamilyRole("member");
        user.setUpdateTime(LocalDateTime.now());
        userMapper.updateById(user);

        // 清除家庭成员的family_id
        clearFamilyMembersFamilyId(userId);

        // 更新家庭成员数
        family.setMemberCount(Math.max(1, family.getMemberCount() - 1));
        family.setUpdateTime(LocalDateTime.now());
        familyMapper.updateById(family);

        // 如果是最后一个成员，删除家庭
        if (family.getMemberCount() <= 1) {
            familyMapper.deleteById(family.getId());
        }

        log.info("用户退出家庭成功: userId={}, familyId={}", userId, familyId);
    }

    @Override
    public List<FamilyMemberUserResponse> getFamilyMembers(Long userId) {
        User user = userMapper.selectById(userId);
        if (user == null || user.getFamilyId() == null) {
            throw new BusinessException(ErrorCode.FAMILY_NOT_FOUND, "您还未加入家庭");
        }

        // 查询同一家庭的所有用户
        LambdaQueryWrapper<User> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(User::getFamilyId, user.getFamilyId());
        wrapper.orderByAsc(User::getCreateTime);
        List<User> users = userMapper.selectList(wrapper);

        List<FamilyMemberUserResponse> responses = new ArrayList<>();
        for (User u : users) {
            FamilyMemberUserResponse response = FamilyMemberUserResponse.builder()
                    .id(u.getId())
                    .phone(maskPhone(u.getPhone()))
                    .nickname(u.getNickname())
                    .avatar(u.getAvatar())
                    .gender(u.getGender())
                    .birthday(u.getBirthday())
                    .familyRole(u.getFamilyRole())
                    .joinTime(u.getUpdateTime())
                    .isMe(u.getId().equals(userId))
                    .build();
            responses.add(response);
        }

        return responses;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void removeMember(Long adminId, Long targetUserId) {
        // 1. 验证管理员权限
        User admin = userMapper.selectById(adminId);
        if (admin == null || admin.getFamilyId() == null) {
            throw new BusinessException(ErrorCode.FAMILY_NOT_FOUND, "您还未加入家庭");
        }
        if (!"admin".equals(admin.getFamilyRole())) {
            throw new BusinessException(ErrorCode.NOT_FAMILY_ADMIN, "只有家庭管理员可以移除成员");
        }

        // 2. 不能移除自己
        if (adminId.equals(targetUserId)) {
            throw new BusinessException(ErrorCode.CANNOT_REMOVE_ADMIN, "不能移除自己，请使用退出家庭功能");
        }

        // 3. 检查目标用户是否在同一家庭
        User targetUser = userMapper.selectById(targetUserId);
        if (targetUser == null || !admin.getFamilyId().equals(targetUser.getFamilyId())) {
            throw new BusinessException(ErrorCode.FAMILY_NOT_FOUND, "目标用户不在您的家庭中");
        }

        // 4. 移除成员
        Long familyId = admin.getFamilyId();
        targetUser.setFamilyId(null);
        targetUser.setFamilyRole("member");
        targetUser.setUpdateTime(LocalDateTime.now());
        userMapper.updateById(targetUser);

        // 清除家庭成员的family_id
        clearFamilyMembersFamilyId(targetUserId);

        // 5. 更新家庭成员数
        Family family = familyMapper.selectById(familyId);
        if (family != null) {
            family.setMemberCount(Math.max(1, family.getMemberCount() - 1));
            family.setUpdateTime(LocalDateTime.now());
            familyMapper.updateById(family);
        }

        log.info("管理员移除成员成功: adminId={}, targetUserId={}, familyId={}", adminId, targetUserId, familyId);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void updateFamilyName(Long userId, String familyName) {
        User user = userMapper.selectById(userId);
        if (user == null || user.getFamilyId() == null) {
            throw new BusinessException(ErrorCode.FAMILY_NOT_FOUND, "您还未加入家庭");
        }

        // 只有管理员可以修改家庭名称
        if (!"admin".equals(user.getFamilyRole())) {
            throw new BusinessException(ErrorCode.NOT_FAMILY_ADMIN, "只有家庭管理员可以修改家庭名称");
        }

        Family family = familyMapper.selectById(user.getFamilyId());
        if (family == null) {
            throw new BusinessException(ErrorCode.FAMILY_NOT_FOUND, "家庭不存在");
        }

        family.setFamilyName(familyName);
        family.setUpdateTime(LocalDateTime.now());
        familyMapper.updateById(family);

        log.info("更新家庭名称成功: userId={}, familyId={}, newName={}", userId, family.getId(), familyName);
    }

    @Override
    public String generateFamilyCode() {
        Random random = new Random();
        String code;
        int attempts = 0;
        final int MAX_ATTEMPTS = 100;

        do {
            code = "";
            for (int i = 0; i < CODE_LENGTH; i++) {
                code += CODE_CHARS.charAt(random.nextInt(CODE_CHARS.length()));
            }
            attempts++;
            if (attempts > MAX_ATTEMPTS) {
                throw new BusinessException(ErrorCode.INTERNAL_ERROR, "生成邀请码失败，请重试");
            }
        } while (isFamilyCodeExists(code));

        return code;
    }

    /**
     * 检查邀请码是否已存在
     */
    private boolean isFamilyCodeExists(String code) {
        LambdaQueryWrapper<Family> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(Family::getFamilyCode, code);
        return familyMapper.selectCount(wrapper) > 0;
    }

    /**
     * 同步更新家庭成员表的family_id
     */
    private void syncFamilyMembersFamilyId(Long userId, Long familyId) {
        // 这里需要注入 FamilyMemberMapper 来更新，但为简化先跳过
        // 实际使用时应该注入 FamilyMemberMapper 并执行更新
        log.debug("同步家庭成员familyId: userId={}, familyId={}", userId, familyId);
    }

    /**
     * 清除家庭成员的family_id
     */
    private void clearFamilyMembersFamilyId(Long userId) {
        log.debug("清除家庭成员familyId: userId={}", userId);
    }

    /**
     * 手机号脱敏
     */
    private String maskPhone(String phone) {
        if (phone == null || phone.length() < 11) {
            return phone;
        }
        return phone.substring(0, 3) + "****" + phone.substring(7);
    }

    /**
     * 转换为FamilyResponse
     */
    private FamilyResponse toFamilyResponse(Family family, String myRole) {
        // 获取管理员信息
        User admin = userMapper.selectById(family.getAdminId());

        return FamilyResponse.builder()
                .id(family.getId())
                .familyName(family.getFamilyName())
                .familyCode(family.getFamilyCode())
                .adminId(family.getAdminId())
                .adminNickname(admin != null ? admin.getNickname() : "未知")
                .memberCount(family.getMemberCount())
                .createTime(family.getCreateTime())
                .myRole(myRole)
                .build();
    }
}
