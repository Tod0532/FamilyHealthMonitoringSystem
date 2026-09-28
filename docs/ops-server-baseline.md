# 服务器运维基线记录

> 采集时间：**2026-09-28 14:39 CST**
> 采集方式：SSH 只读命令（`uname` / `/proc` / `df` / `SHOW GLOBAL STATUS`）
> 服务器：阿里云 ECS `iZm5e3qyj775jrq7zkm7keZ` · 公网 `139.129.108.119`

⚠️ **本文档不含任何密码/密钥。** 凭据位置见文末「凭据位置索引」。

---

## 一、主机与系统

| 项目 | 值 |
|---|---|
| 操作系统 | Ubuntu 22.04.5 LTS |
| 内核 | 5.15.0-164-generic |
| CPU | **2 核** |
| 内存 | **1608 MB**（采集时可用 505 MB）|
| Swap | **2047 MB**（2026-09-28 新增，见第二节）|
| 根分区 | 40 G 总量 / 30 G 可用（**22%** 已用）|
| 系统运行时长 | **236.2 天** |

## 二、2026-09-28 本次改动记录

| 改动 | 内容 | 验证方式 |
|---|---|---|
| **新增 swap** | `/swapfile` 2 GB，写入 `/etc/fstab`（UUID `93bc3394-…`） | `swapoff /swapfile && swapon -a` 成功 |
| **开启慢查询日志** | `/etc/mysql/mysql.conf.d/zz-slow-query.cnf`：`slow_query_log=ON`、`long_query_time=1`、`log_queries_not_using_indexes=OFF` | `mysqld --validate-config` 通过后重启 |
| **MySQL 重启** | 具体原因：应用慢查询配置 | 停机 **4.999 秒**；重启后应用重连正常、生产登录 HTTP 200 |

**改动前状态（供回滚参考）**：无 swap；`slow_query_log=OFF`、`long_query_time=10`。

**备份文件**：`/etc/fstab.bak.20260928`（改动前的原始 fstab）。

## 三、MySQL 状态基线

| 指标 | 值 |
|---|---|
| 版本 | 8.0.46-0ubuntu0.22.04.4 |
| MySQL 运行时长 | 688 秒（≈11 分钟，因本次重启清零）|
| `Aborted_connects` | **0** ← 已随重启清零，**这是本次建立的观测基线** |
| `Connections` | 65（重启后累计）|
| `Max_used_connections` | 12 |
| `Threads_connected` | 11 |
| `Slow_queries` | 0（慢日志刚开启，此值从此刻起才有意义）|

### 关于 `Aborted_connects` 的排查结论

**结论：不是持续被扫描，而是 25 天累积。**

| 观测 | 数据 |
|---|---|
| 重启前累积值 | 2804 次 / 25.4 天 ≈ **112 次/天** |
| 90 秒观测增量 | **0** |
| `Connections` 增速 | +4 / 90 秒 ≈ 0.04 次/秒（全部来自应用连接池）|
| 服务器日志新增行 | 90 秒内 **0 行** |

> 由于计数已清零，**后续可直接观察真实增速**，无需再靠 25 天的平均值推断。

### 日志中出现过的未识别外部 IP（历史，来自 `error.log.*.gz`）

```
124.89.90.54      外部，非本项目来源 —— 疑似扫描/探测
36.250.221.86     外部，非本项目来源 —— 疑似扫描/探测
111.15.8.239      本机出口 IP（DB 查看器所在网络的公网地址）
139.129.108.119   服务器自身公网 IP（应用经公网回环连接）
```

## 四、待处理的加固项（**暂缓，未执行**）

决策：**2026-09-28 决定暂不改动**，仅记录待后续处理。

### 风险点 1：MySQL 监听公网

```
bind_address = 0.0.0.0
LISTEN 0.0.0.0:3306      ← 公网可达
```

### 风险点 2：存在通配来源的用户账号

```
health_app@%           mysql_native_password   ← 允许从任意 IP 登录
health_app@localhost   caching_sha2_password
root@localhost         auth_socket             ← 安全，无法远程登录
```

⚠️ **注意**：`health_app@%` 与 `health_app@localhost` **是两个独立的账号**，
认证插件不同（前者 `mysql_native_password` 已废弃），
意味着「本机连接的密码」与「远程连接的密码」是分开维护的。

### 建议的加固方案（三选一）

| 方案 | 操作 | 停机 | 效果 |
|---|---|---|---|
| **A. 完整加固**（推荐）| `bind-address=127.0.0.1` + `DROP USER 'health_app'@'%'` + 查看器改用 SSH 隧道 | ~5 秒 | 3306 不再对公网监听，扫描器彻底够不着 |
| B. 只删通配账号 | `DROP USER 'health_app'@'%'` | 0 | 外部仍能建 TCP 连接但登不进来 |
| C. 仅观察 | 无 | 0 | 暴露面继续存在 |

**选 A 的副作用与配套**：数据库查看器当前是**直连公网 3306**，改后需改用 SSH 隧道：

```powershell
# 终端 1：保持隧道（13306 -> 服务器 3306）
ssh -N -L 13306:localhost:3306 aliyun

# 终端 2：查看器指向本地隧道端口
cd D:\ReadHealthInfo\scripts\dbviewer
java "-Dfile.encoding=UTF-8" "-Ddb.url=jdbc:mysql://127.0.0.1:13306/health_center_db?useSSL=false&serverTimezone=Asia/Shanghai&allowPublicKeyRetrieval=true" `
     -cp ".;mysql-connector-j.jar" DbViewer
```

**还需在阿里云控制台**关闭安全组 3306 入方向规则（服务器侧无法修改）。

## 五、其它已发现但未处理的问题

| 问题 | 说明 |
|---|---|
| 内存偏紧 | 1.6 GB 内存 + MySQL + Java；swap 只是兜底，升配到 2–4 GB 才是根治 |
| 连接中止历史 | 2804 次 / 25 天，来源见第三节 |
| 应用以 root 运行 | systemd `health-app.service` 为 `User=root` |
| 无 TLS | 应用 8080 明文 HTTP，无 nginx |
| 凭据进入 git 历史 | 见下方索引；`.gitignore` 对已跟踪文件无效，需轮换 + 必要时重写历史 |

## 六、如何复核本基线

```powershell
# 主机指标（也可直接看查看器的「服务器状态」页）
ssh aliyun 'free -m; df -h /; swapon --show; uptime'

# MySQL 指标（也可看查看器的「MySQL 运行时指标」面板）
ssh aliyun "mysql -u root -e \"SHOW GLOBAL STATUS WHERE Variable_name IN ('Uptime','Aborted_connects','Connections','Slow_queries');\""

# 慢查询日志
ssh aliyun 'tail -50 /var/lib/mysql/slow.log'
```

可视化入口：**http://127.0.0.1:18090** →「服务器状态」

## 七、凭据位置索引（**不在此处复制凭据**）

需要凭据时请到以下位置查看，并注意这些文件可能处于版本控制中：

| 位置 | 内容 |
|---|---|
| `deploy/server/application-prod.yml` | 数据库账号密码 |
| `spring-boot-backend/src/main/resources/application-dev.yml` | JWT 密钥 |
| `spring-boot-backend/src/main/resources/application-prod.yml` | 数据库账号密码 |
| `docs/aliyun-deployment.md` | ⚠️ 含服务器 SSH root 凭据 |
| `scripts/dbviewer/DbViewer.java` | 数据库连接默认值（该目录已被 `.gitignore` 忽略）|
| 本机 `~/.ssh/config` | SSH 主机别名 `aliyun`（密钥认证，无密码）|

## 八、磁盘上可清理的遗留文件

| 文件 | 说明 |
|---|---|
| `/etc/fstab.broken.20260928b` | 改动过程中产生的中间错误版本，**可删** |
| `/etc/fstab.new` | 候选版本，已安装，**可删** |
| `/etc/fstab.prev.20260928` | 安装前备份，**建议保留** |
| `/etc/fstab.bak.20260928` | 原始 fstab 备份，**建议保留** |

---

*本文件由只读排查 + 变更记录整理而成，用于后续对比与决策。*
