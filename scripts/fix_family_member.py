#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
修复 family_member 数据不一致（Fix 6/6）

问题（实测）
  user.family_id 指向某家庭、但 family_member 表里没有对应行的用户共 4 个：
      TestUser / UserB -> 家庭 2019604459758014466
      哈哈             -> 家庭 2019651977891938306
      涛               -> 家庭 2022508135879266306
  后果：GET /api/family/members 对这些家庭返回 0 条 —— App"家庭成员"为空，
        而 /api/family/my 又说 member_count=1，自相矛盾。

  family.member_count 原为手工累加，已与 family_member 实际行数漂移。

修复步骤
  1. 预演：把待插入的行插到一张 TEMPORARY 表，验证 SQL 与取值（不碰真实数据）
  2. 备份 family / family_member
  3. 正式插入缺失行（幂等：已存在的用户会跳过）
  4. 按实际行数重算 family.member_count
  5. 核对

安全
  * 只做 INSERT / UPDATE，绝不 DELETE 任何业务数据
  * 幂等，可重复执行
"""
import subprocess
import sys

sys.stdout.reconfigure(encoding="utf-8")

DB = "health_center_db"
TS = "20260928b"


def mysql(sql, show=True):
    p = subprocess.run(["mysql", "-u", "root", DB], input=sql,
                       capture_output=True, text=True, encoding="utf-8")
    if p.returncode != 0:
        print("  !! mysql 错误:", p.stderr.strip()[:400])
    if show and p.stdout.strip():
        print(p.stdout.rstrip())
    return p.stdout


def fetch(sql):
    """取数据行（-N 关闭表头），用于程序化处理"""
    p = subprocess.run(["mysql", "-u", "root", "-N", DB], input=sql,
                       capture_output=True, text=True, encoding="utf-8")
    if p.returncode != 0:
        print("  !! mysql 错误:", p.stderr.strip()[:400])
    return [l.split("\t") for l in p.stdout.strip().splitlines() if l.strip()]


FIND_SQL = """
SELECT u.id, u.nickname, u.family_id,
       COALESCE(u.family_role, 'member'),
       COALESCE(u.gender, 'male'),
       COALESCE(u.birthday, '1990-01-01'),
       u.avatar
FROM user u
WHERE u.family_id IS NOT NULL
  AND u.deleted = 0
  AND NOT EXISTS (
        SELECT 1 FROM family_member fm
        WHERE fm.user_id = u.id AND fm.family_id = u.family_id AND fm.deleted = 0
      )
ORDER BY u.family_id, u.id;
"""

print("=" * 100)
print("步骤 1：找出需要补行的用户")
print("=" * 100)
need = fetch(FIND_SQL)
if not need:
    print("  没有需要补行的用户 —— 无需修复")
else:
    for r in need:
        print("  user=%-20s %-10s -> family=%-20s role=%s" % (r[0], r[1], r[2], r[3]))


def esc(v):
    if v in (None, "", "NULL"):
        return "NULL"
    return "'" + str(v).replace("\\", "\\\\").replace("'", "''") + "'"


# 生成待插入行（用显式 ID，区段避开既有雪花 ID，防止碰撞）
BASE_ID = 2026120900000000000
rows = []
for i, r in enumerate(need):
    uid, nick, fid, role, gender, bday, avatar = r
    rows.append("(%d, %d, %d, %s, %s, 'other', %s, %s, %s, 0, NOW(), NOW(), 0)" % (
        BASE_ID + i + 1, int(uid), int(fid), esc(nick), esc(gender),
        esc(role if role in ("admin", "member", "guest") else "member"),
        esc(bday), esc(avatar)))

INSERT_SQL = """INSERT INTO family_member
  (id, user_id, family_id, name, gender, relation, role, birthday, avatar, sort_order, create_time, update_time, deleted)
VALUES
%s;""" % (",\n".join(rows))

print()
print("=" * 100)
print("步骤 2：预演 —— 插到 TEMPORARY 表验证（不触碰真实数据）")
print("=" * 100)
if rows:
    # 用临时表复制结构，跑一遍同样的 INSERT 语句，确认列数与类型匹配
    pre = """
CREATE TEMPORARY TABLE tmp_fm LIKE family_member;
%s
SELECT COUNT(*) AS 预演插入行数 FROM tmp_fm;
""" % INSERT_SQL.replace("INSERT INTO family_member", "INSERT INTO tmp_fm")
    mysql(pre)
else:
    print("  无需插入")

print()
print("=" * 100)
print("步骤 3：备份")
print("=" * 100)
mysql("""
DROP TABLE IF EXISTS `family_bak_%s`;
DROP TABLE IF EXISTS `family_member_bak_%s`;
CREATE TABLE `family_bak_%s`        LIKE `family`;
INSERT INTO `family_bak_%s`        SELECT * FROM `family`;
CREATE TABLE `family_member_bak_%s` LIKE `family_member`;
INSERT INTO `family_member_bak_%s` SELECT * FROM `family_member`;
SELECT '备份完成' AS 状态,
       (SELECT COUNT(*) FROM family_bak_%s)        AS family行数,
       (SELECT COUNT(*) FROM family_member_bak_%s) AS member行数;
""" % (TS, TS, TS, TS, TS, TS, TS, TS))

print()
print("=" * 100)
print("步骤 4：正式插入缺失行")
print("=" * 100)
if rows:
    # 再跑一次 FIND，确认此刻仍缺（避免步骤 1 之后的状态变化）
    still = fetch(FIND_SQL)
    if not still:
        print("  状态已变化：当前无缺失，跳过插入")
    else:
        mysql(INSERT_SQL)
        print("  已插入 %d 行" % len(rows))
else:
    print("  无需插入")

print()
print("=" * 100)
print("步骤 5：按实际行数重算 family.member_count")
print("=" * 100)
mysql("""
UPDATE family f
SET f.member_count = (SELECT COUNT(*) FROM family_member fm
                      WHERE fm.family_id = f.id AND fm.deleted = 0),
    f.update_time = NOW()
WHERE f.deleted = 0;
""")

print()
print("=" * 100)
print("步骤 6：核对")
print("=" * 100)
mysql("""
SELECT f.id AS 家庭ID, f.family_name AS 家庭名,
       f.member_count AS 计数字段, COUNT(fm.id) AS 实际行数,
       IF(f.member_count = COUNT(fm.id), 'OK', '不一致') AS 结果
FROM family f
LEFT JOIN family_member fm ON fm.family_id = f.id AND fm.deleted = 0
WHERE f.deleted = 0
GROUP BY f.id, f.family_name, f.member_count ORDER BY f.id;
""")
mysql("""
SELECT u.id AS 用户, u.nickname AS 昵称, u.family_id AS 家庭,
       u.family_role AS 角色,
       (SELECT COUNT(*) FROM family_member fm
        WHERE fm.user_id = u.id AND fm.family_id = u.family_id AND fm.deleted = 0) AS 成员行数
FROM user u WHERE u.family_id IS NOT NULL AND u.deleted = 0
ORDER BY u.family_id, u.id;
""")
print("=" * 100)
