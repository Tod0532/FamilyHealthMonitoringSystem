# 成员ID不一致问题修复记录

## 问题描述
**日期**：2026-02-14
**现象**：添加健康数据时提示"成员不存在"

## 问题排查过程

### 1. 现象确认
- 手机APP添加健康数据时提示"操作失败"
- 后端日志显示：`BusinessException: 成员不存在`

### 2. 日志分析
```bash
# 查看后端错误日志
grep -A 30 '成员不存在' /opt/health-center/logs/health-center.log
```

错误堆栈指向 `HealthDataServiceImpl.validateMember()` 方法第307行

### 3. 代码检查
检查 `validateMember()` 方法：
```java
private void validateMember(Long memberId, Long userId) {
    FamilyMember member = familyMemberMapper.selectById(memberId);
    if (member == null) {
        throw new BusinessException(ErrorCode.MEMBER_NOT_FOUND, "成员不存在");
    }
    // ...
}
```

### 4. 数据检查
```sql
-- 检查 API 返回的成员列表
SELECT id, phone, nickname, family_id FROM user WHERE family_id = xxx;

-- 检查 family_member 表的数据
SELECT id, user_id, name FROM family_member WHERE family_id = xxx;
```

发现两个表的ID完全不一样：
- `user.id` = 2019651847365197826
- `family_member.id` = 2019670046592958465

### 5. 根本原因
`getFamilyMembers()` API 从 `user` 表查询并返回 `user.id`
但 `validateMember()` 检查的是 `family_member` 表

前端使用API返回的 `user.id` 作为 `memberId` 发送请求
后端用这个ID去查 `family_member` 表，当然找不到！

## 解决方案

### 修改文件
`spring-boot-backend/src/main/java/com/health/service/impl/FamilyServiceImpl.java`

### 修改内容
**修改前**（第245-274行）：
```java
public List<FamilyMemberUserResponse> getFamilyMembers(Long userId) {
    // 从 user 表查询
    List<User> users = userMapper.selectList(wrapper);

    for (User u : users) {
        response.id(u.getId());  // ❌ 返回 user.id
        response.nickname(u.getNickname());
        // ...
    }
}
```

**修改后**：
```java
public List<FamilyMemberUserResponse> getFamilyMembers(Long userId) {
    // 从 family_member 表查询
    List<FamilyMember> members = familyMemberMapper.selectList(wrapper);

    for (FamilyMember member : members) {
        response.id(member.getId());  // ✅ 返回 family_member.id
        response.nickname(member.getName());  // ✅ 使用 family_member.name

        // 关联 user 表获取其他信息
        User u = userMapper.selectById(member.getUserId());
        response.phone(maskPhone(u.getPhone()));
        // ...
    }
}
```

## 其他发现的问题

### 成员名称获取错误
**文件**：`HealthDataServiceImpl.java` 第329行
**问题**：调用 `member.getNickname()` 但 `FamilyMember` 实体字段是 `name`
**修复**：改为 `member.getName()`

## 验证结果

```bash
# 测试 API 返回的成员 ID
curl http://139.129.108.119:8080/api/family/members
```

修改前：返回 `user.id`
修改后：返回 `family_member.id`

## 经验总结

1. **关联表查询时，必须返回目标表的主键ID**
   - 如果业务需要 `family_member` 的信息，就应该返回 `family_member.id`

2. **实体类字段要与getter方法一致**
   - 检查实体类定义，避免调用不存在的方法

3. **数据不一致问题排查步骤**
   - 先确认API返回的数据
   - 再确认数据库实际数据
   - 检查代码使用的表是否一致
