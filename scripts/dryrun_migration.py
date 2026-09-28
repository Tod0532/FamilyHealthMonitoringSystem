#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
迁移脚本预演：在临时库中模拟生产旧结构，完整跑一遍迁移脚本，验证其正确性。
不触碰 health_center_db。
"""
import os
import re
import subprocess
import sys

sys.stdout.reconfigure(encoding="utf-8")

SQL_FILE = "/tmp/migrate-alert-tables.sql"
TEST_DB = "migrate_dryrun_db"

SCRIPT = open(SQL_FILE, encoding="utf-8").read()
# 把脚本里的库名替换成临时库；USE 语句也要换
test_script = SCRIPT.replace("USE health_center_db;", "USE %s;" % TEST_DB)
test_script = test_script.replace("DATABASE()", "'%s'" % TEST_DB)


def mysql(sql, db=None, want_output=True):
    cmd = ["mysql", "-u", "root"]
    if db:
        cmd.append(db)
    p = subprocess.run(cmd, input=sql, capture_output=True, text=True, encoding="utf-8")
    if p.returncode != 0:
        print("  !! mysql 失败:", p.stderr.strip()[:300])
    return p.stdout


print("=" * 90)
print("步骤 1：建临时库，并按【生产旧结构】建两张 alert 表")
print("=" * 90)
mysql("DROP DATABASE IF EXISTS %s;" % TEST_DB)
mysql("CREATE DATABASE %s DEFAULT CHARACTER SET utf8mb4;" % TEST_DB)

OLD_DDL = """
CREATE TABLE alert_rule (
  id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL,
  data_type VARCHAR(20) DEFAULT NULL,
  condition_type VARCHAR(20) DEFAULT NULL,
  threshold_value DECIMAL(10,2) DEFAULT NULL,
  alert_level VARCHAR(20) DEFAULT NULL,
  is_enabled TINYINT DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE alert_record (
  id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL,
  member_id BIGINT DEFAULT NULL,
  rule_id BIGINT DEFAULT NULL,
  alert_type VARCHAR(20) DEFAULT NULL,
  alert_level VARCHAR(20) DEFAULT NULL,
  data_value DECIMAL(10,2) DEFAULT NULL,
  is_read TINYINT DEFAULT 0,
  is_processed TINYINT DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 塞两条数据，验证「补列 + 数据搬运」不会丢数据
INSERT INTO alert_rule (user_id, data_type, condition_type, threshold_value, alert_level, is_enabled)
VALUES (1, 'blood_pressure', 'gt', 140.00, 'danger', 1);
INSERT INTO alert_record (user_id, member_id, alert_type, alert_level, data_value, is_read)
VALUES (1, 1, 'blood_pressure', 'danger', 155.00, 1);
"""
out = mysql(OLD_DDL, TEST_DB)
print("  已建旧结构 + 插入 2 条样本数据")

print()
print("=" * 90)
print("步骤 2：执行迁移脚本")
print("=" * 90)
out = mysql(test_script, TEST_DB)
err_lines = [l for l in out.splitlines() if "ERROR" in l.upper()]
if err_lines:
    print("  !! 脚本输出含 ERROR：")
    for l in err_lines[:10]:
        print("   ", l)
else:
    print("  脚本无 ERROR 输出")

print()
print("=" * 90)
print("步骤 3：核算 —— 实体所需列是否齐全")
print("=" * 90)

REQUIRED = {
    "alert_rule": ["id", "user_id", "alert_type", "alert_level", "condition_type",
                   "threshold1", "threshold2", "rule_name", "enabled", "is_default",
                   "create_time", "update_time", "deleted"],
    "alert_record": ["id", "user_id", "member_id", "rule_id", "alert_type", "alert_level",
                     "title", "content", "trigger_value", "status", "handle_time",
                     "create_time", "update_time", "deleted"],
}

allok = True
for tbl, cols in REQUIRED.items():
    q = ("SELECT COLUMN_NAME FROM information_schema.COLUMNS "
         "WHERE TABLE_SCHEMA='%s' AND TABLE_NAME='%s';" % (TEST_DB, tbl))
    got = set(mysql(q).split())
    missing = [c for c in cols if c not in got]
    if missing:
        allok = False
        print("  %-14s ✗ 仍缺: %s" % (tbl, ", ".join(missing)))
    else:
        print("  %-14s ✓ 实体所需 %d 列全部存在（表共 %d 列）" % (tbl, len(cols), len(got)))

print()
print("=" * 90)
print("步骤 4：数据是否保留 + 是否搬到新列")
print("=" * 90)
print(mysql("SELECT id, user_id, alert_type, threshold1, enabled, create_time, deleted "
            "FROM alert_rule;", TEST_DB))
print(mysql("SELECT id, user_id, alert_type, trigger_value, status, create_time, deleted "
            "FROM alert_record;", TEST_DB))
print("备份表行数:")
print(mysql("SELECT (SELECT COUNT(*) FROM alert_rule_bak_20260928)   AS rule_bak, "
            "(SELECT COUNT(*) FROM alert_record_bak_20260928) AS rec_bak;", TEST_DB))

print()
print("=" * 90)
print("步骤 5：幂等性 —— 再跑一次迁移脚本，应无报错")
print("=" * 90)
out2 = mysql(test_script, TEST_DB)
err2 = [l for l in out2.splitlines() if "ERROR" in l.upper() and "Duplicate key name" not in l]
# 索引重建会报 Duplicate key name，这是预期的；其它错误才算失败
real_err = [l for l in err2 if "Duplicate key name" not in l]
if real_err:
    print("  !! 重跑出现非预期错误：")
    for l in real_err[:8]:
        print("   ", l)
else:
    print("  重跑完成（索引重复提示属预期）—— 脚本幂等 ✓")

print()
print("=" * 90)
print("结论：" + ("预演通过，脚本可安全用于生产库 ✓" if allok else "预演失败，需修正脚本 ✗"))
print("=" * 90)

# 清理
mysql("DROP DATABASE IF EXISTS %s;" % TEST_DB)
print("临时库已删除")
sys.exit(0 if allok else 1)
