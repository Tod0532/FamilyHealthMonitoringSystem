package com.health.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.health.domain.entity.Family;
import com.health.domain.entity.FamilyMember;
import com.health.domain.entity.User;
import com.health.domain.mapper.FamilyMapper;
import com.health.domain.mapper.FamilyMemberMapper;
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
    private final FamilyMemberMapper familyMemberMapper;

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

        // 5. 创建family_member记录（管理员）
        FamilyMember familyMember = new FamilyMember();
        familyMember.setUserId(userId);
        familyMember.setFamilyId(family.getId());
        familyMember.setName(user.getNickname() != null ? user.getNickname() : "管理员");
        familyMember.setGender(user.getGender());
        familyMember.setRelation("other"); // 默认关系，可后续修改
        familyMember.setRole("admin");
        familyMember.setBirthday(user.getBirthday());
        familyMember.setAvatar(user.getAvatar());
        familyMember.setCreateTime(LocalDateTime.now());
        familyMember.setUpdateTime(LocalDateTime.now());
        familyMemberMapper.insert(familyMember);

        // 6. 校正该用户在其他家庭遗留的成员行归属（原为空方法，导致孤儿行）
        syncFamilyMembersFamilyId(userId, family.getId());
        // 7. 以实际行数重算成员数，避免手工累加造成漂移
        recalcMemberCount(family.getId());

        log.info("用户创建家庭成功: userId={}, familyId={}, familyCode={}", userId, family.getId(), familyCode);

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

        // 3. 加入家庭（更新用户表）
        user.setFamilyId(family.getId());
        user.setFamilyRole("member");
        user.setUpdateTime(LocalDateTime.now());
        userMapper.updateById(user);

        // 4. 创建family_member记录
        FamilyMember familyMember = new FamilyMember();
        familyMember.setUserId(userId);
        familyMember.setFamilyId(family.getId());
        familyMember.setName(user.getNickname() != null ? user.getNickname() : "家庭成员");
        familyMember.setGender(user.getGender());
        familyMember.setRelation("other"); // 默认关系，可后续修改
        familyMember.setRole("member");
        familyMember.setBirthday(user.getBirthday());
        familyMember.setAvatar(user.getAvatar());
        familyMember.setCreateTime(LocalDateTime.now());
        familyMember.setUpdateTime(LocalDateTime.now());
        familyMemberMapper.insert(familyMember);

        // 5. 校正该用户遗留在其他家庭的成员行，并按实际行数重算成员数
        //    （原先手工 memberCount+1 会与实际行数漂移，线上已出现计数字段=1 而实际行数=0）
        syncFamilyMembersFamilyId(userId, family.getId());
        recalcMemberCount(family.getId());
        // 重新读回，保证返回给客户端的 memberCount 是最新值
        Family latest = familyMapper.selectById(family.getId());

        log.info("用户加入家庭成功: userId={}, familyId={}, familyCode={}", userId, family.getId(), family.getFamilyCode());

        return toFamilyResponse(latest != null ? latest : family, "member");
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
            // 语义修正：原用 NOT_FAMILY_ADMIN（"您不是家庭管理员"）表达
            // "管理员不能退出"，与事实相反，改用 CANNOT_REMOVE_ADMIN
            throw new BusinessException(ErrorCode.CANNOT_REMOVE_ADMIN, "管理员不能退出，请先转让管理员或解散家庭");
        }

        // 清除用户在 family_member 中的归属（原为空方法 ⇒ 孤儿行）
        Long familyId = user.getFamilyId();
        user.setFamilyId(null);
        user.setFamilyRole("member");
        user.setUpdateTime(LocalDateTime.now());
        userMapper.updateById(user);

        int cleared = clearFamilyMembersFamilyId(userId);

        // 以剩余实际行数判定家庭是否已空，而不是依赖会漂移的 memberCount 手工加减
        LambdaQueryWrapper<FamilyMember> remain = new LambdaQueryWrapper<>();
        remain.eq(FamilyMember::getFamilyId, familyId);
        Long remaining = familyMemberMapper.selectCount(remain);
        boolean familyEmpty = (remaining == null || remaining == 0);

        if (familyEmpty) {
            // 已无任何成员，删除家庭（逻辑删除）
            familyMapper.deleteById(familyId);
            log.info("家庭已无成员，已删除: familyId={}", familyId);
        } else {
            recalcMemberCount(familyId);
        }

        log.info("用户退出家庭成功: userId={}, familyId={}, 清理成员行={}, 家庭剩余成员={}",
                userId, familyId, cleared, remaining);
    }

    @Override
    public List<FamilyMemberUserResponse> getFamilyMembers(Long userId) {
        User user = userMapper.selectById(userId);
        if (user == null || user.getFamilyId() == null) {
            throw new BusinessException(ErrorCode.FAMILY_NOT_FOUND, "您还未加入家庭");
        }

        // 查询同一家庭的所有成员（从 family_member 表）
        LambdaQueryWrapper<FamilyMember> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(FamilyMember::getFamilyId, user.getFamilyId());
        wrapper.orderByAsc(FamilyMember::getSortOrder);
        wrapper.orderByAsc(FamilyMember::getCreateTime);
        List<FamilyMember> members = familyMemberMapper.selectList(wrapper);

        // 查询这些成员对应的用户信息
        List<FamilyMemberUserResponse> responses = new ArrayList<>();
        for (FamilyMember member : members) {
            User u = userMapper.selectById(member.getUserId());
            if (u == null) continue; // 跳过无效用户

            FamilyMemberUserResponse response = FamilyMemberUserResponse.builder()
                    .id(member.getId())  // 返回 family_member.id
                    .phone(maskPhone(u.getPhone()))
                    .nickname(member.getName())  // 使用 family_member.name
                    .avatar(u.getAvatar())
                    .gender(u.getGender())
                    .birthday(u.getBirthday())
                    .familyRole(member.getRole())
                    .joinTime(member.getCreateTime())
                    .isMe(member.getUserId().equals(userId))
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

        // 清除该用户在 family_member 中的归属（原为空方法 ⇒ 孤儿行）
        int cleared = clearFamilyMembersFamilyId(targetUserId);

        // 5. 以实际行数重算成员数（替代原先会漂移的手工累减）
        recalcMemberCount(familyId);

        log.info("管理员移除成员成功: adminId={}, targetUserId={}, familyId={}, 清理成员行={}",
                adminId, targetUserId, familyId, cleared);

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
     * 把指定用户的家庭成员行归属到目标家庭。
     *
     * <p><b>实现说明</b>：原实现为空方法（仅一行 log.debug），导致 family_member
     * 表长期存在 family_id 为空的孤儿行 —— 这些行在按 family_id 查询成员时
     * 不可见，于是 App 出现"家庭有 N 人但成员列表为空"的现象。</p>
     *
     * <p>这里不做"补建缺失行"，因为一个用户可能同时作为多个家庭的成员被登记
     * （历史数据即如此），盲目补建会造出错误归属。加入/创建家庭时已会插入
     * 正确归属的行，本方法只负责把该用户<b>遗留在其他家庭</b>的行校正过来。</p>
     */
    private void syncFamilyMembersFamilyId(Long userId, Long familyId) {
        LambdaQueryWrapper<FamilyMember> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(FamilyMember::getUserId, userId);
        List<FamilyMember> members = familyMemberMapper.selectList(wrapper);
        for (FamilyMember m : members) {
            if (!familyId.equals(m.getFamilyId())) {
                m.setFamilyId(familyId);
                m.setUpdateTime(LocalDateTime.now());
                familyMemberMapper.updateById(m);
                log.info("已校正家庭成员归属: memberId={}, userId={}, -> familyId={}",
                        m.getId(), userId, familyId);
            }
        }
    }

    /**
     * 把指定用户在 family_member 中的归属清空。
     *
     * <p>退出 / 被移除家庭时调用。<b>不是删除行</b>，而是把 family_id 置空 ——
     * 因为同一张 family_member 表可能同时保存该用户在其他家庭的记录，
     * 直接删除会误伤。置空后这些行不再出现在任何家庭的成员列表中。</p>
     *
     * <p>原实现为空方法，是本项目"成员列表为空""member_count 与实际行数
     * 不一致"等数据漂移问题的根因。</p>
     *
     * @return 实际被清空归属的行数
     */
    private int clearFamilyMembersFamilyId(Long userId) {
        LambdaQueryWrapper<FamilyMember> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(FamilyMember::getUserId, userId);
        wrapper.isNotNull(FamilyMember::getFamilyId);
        List<FamilyMember> members = familyMemberMapper.selectList(wrapper);
        int affected = 0;
        for (FamilyMember m : members) {
            m.setFamilyId(null);
            m.setUpdateTime(LocalDateTime.now());
            familyMemberMapper.updateById(m);
            affected++;
        }
        if (affected > 0) {
            log.info("已清空家庭成员归属: userId={}, 影响 {} 行", userId, affected);
        } else {
            log.debug("无需要清空的家庭成员归属: userId={}", userId);
        }
        return affected;
    }

    /**
     * 按 family_member 表的实际行数重算并写回 family.member_count。
     *
     * <p>原实现以 `memberCount + 1` / `- 1` 手工累加，一旦出现并发或异常路径
     * 就会与实际行数永久漂移（线上已出现计数字段=1 而实际行数=0 的情况）。
     * 改为以实际行数为唯一真相来源。</p>
     */
    private void recalcMemberCount(Long familyId) {
        if (familyId == null) return;
        LambdaQueryWrapper<FamilyMember> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(FamilyMember::getFamilyId, familyId);
        Long actual = familyMemberMapper.selectCount(wrapper);
        Family family = familyMapper.selectById(familyId);
        if (family == null) return;
        int count = actual == null ? 0 : actual.intValue();
        if (family.getMemberCount() == null || family.getMemberCount() != count) {
            log.info("重算家庭成员数: familyId={}, {} -> {}", familyId, family.getMemberCount(), count);
            family.setMemberCount(count);
            family.setUpdateTime(LocalDateTime.now());
            familyMapper.updateById(family);
        }
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
