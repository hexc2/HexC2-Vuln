# musl-ssh-bypass

> **在线靶场**：[hexc2.com/laboratory/targets/118](https://hexc2.com/laboratory/targets/118)
> 登录后启动实例，VPN 接入即可访问 80 端口官网与 22 端口 SSH。

OpenSSH 在 **musl libc + 未启用 PAM** 环境下，`/etc/shadow` 密码字段为 `*` 的账户
可被 257–1024 字节的任意密码登录。

- 漏洞编号：QVD-2026-104595（截至写作时未见 CVE 编号）
- 影响版本：OpenSSH < 10.6p2（2016 年以后），运行于 musl 且密码认证不经过 PAM
- 修复版本：OpenSSH 10.6p2

## 影响条件

四条同时成立才会被绕过：

1. Linux + musl libc（Alpine、OpenWrt、Buildroot、Yocto、musl 的 Docker 镜像）
2. sshd 未使用 PAM：编译时未启用，或运行时 `UsePAM no`
3. `PasswordAuthentication yes`
4. `/etc/shadow` 中存在密码字段恰为 `*` 的账户，**且系统里另有一个持有真实密码哈希的账户**

第 4 条的后半句很关键：`pick_salt()` 需要从某个真实哈希（如 `$6$...$`）借一个盐，
如果全机账户都是 `*` 或 `!`，这条链走不通。很多复现失败是卡在这里。

不受影响：glibc / libxcrypt 系统、非 Linux、PAM 正常参与密码认证的 sshd、密码字段为 `!` 的账户。

## 原理

1. musl 的 `crypt(3)` 计算失败时返回字符串 `"*"`，而不是 POSIX 期望的 `NULL`。
   密码超过 256 字节（sha512crypt 的 `KEY_MAX`）就是失败路径之一。
2. `"*"` 同时是 shadow 里“账户已锁定、无可用密码”的惯用标记。
3. 非 PAM 路径下 sshd 会对锁定账户也调用 `crypt()` 做时序均衡：
   `encrypted_password = xcrypt(password, salt)`，然后 `strcmp(encrypted_password, pw_password)`。
4. 长密码让 musl 返回 `"*"`，与 shadow 里的 `"*"` 相等，认证通过。

**为什么要第二次尝试**：第一次调用 `pick_salt()` 时会遍历账户、覆盖
`getspnam()` 的静态缓冲，把 `pw_password` 指针指向的内容破坏掉，所以第一次必然失败；
同时盐被缓存下来，第二次直接复用，比较才成立。

## 环境构成

| 项 | 说明 |
|---|---|
| 基础镜像 | Alpine 3.22（musl 1.2.5） |
| sshd | 源码编译 OpenSSH 10.5p1，`--without-pam` |
| root | shadow 密码字段 `*`，`PermitRootLogin yes` |
| seed | 持有真实 `$6$` 哈希（口令 `Seed@2026`），用来“借盐” |
| flag | `/root/flag.txt`，默认 `flag{musl_crypt_r3turns_st4r}` |
| 端口 | **80** 静态官网（HEXC2LABS，信息收集入口）；**22** sshd（攻击面） |

镜像里刻意保留 `seed` 账户：它既是学员的立足点（确认系统是 musl、看 sshd 版本），
也是漏洞成立的必要条件之一。

## 构建

```bash
docker build -t hexc2/musl-ssh-bypass:1.0 .
```

构建时会从 `cdn.openbsd.org` 下载 OpenSSH 10.5p1 源码并编译，首次约 1–2 分钟。

网络受限时可以离线构建：

```bash
# 先在能出网的机器上下载
curl -LO https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-10.5p1.tar.gz

# 放到当前目录，用离线模式（把 Dockerfile.offline 作为构建文件）
docker build -f Dockerfile.offline -t hexc2/musl-ssh-bypass:1.0 .
```

## 启动

```bash
docker run -d --name musl-ssh-bypass \
  -p 127.0.0.1:8080:80 \
  -p 127.0.0.1:2222:22 \
  hexc2/musl-ssh-bypass:1.0
```

容器里跑两个服务：

- **80** — nginx 托管的 HEXC2LABS 官网，纯静态页，给学员当信息收集入口
- **22** — sshd，真正的攻击面

浏览器先开 `http://127.0.0.1:8080/` 看页面，再用 `./verify.sh` 打 22。

或：

```bash
docker compose up -d --build
```

映射到宿主 `127.0.0.1:2222` 即可，**不要**直接 `-p 22:22` 或暴露到公网。

## 验证

```bash
./verify.sh 127.0.0.1 2222
```

脚本做的事：用 `ssh` 客户端连一次，在**同一连接内**提交两次 300 字节密码，然后执行 `id`。

预期输出：

```
[VULN] root@127.0.0.1:2222 logged in with 300-byte password
uid=0(root) gid=0(root) groups=0(root),1(bin),2(daemon),3(sys),4(adm),6(disk),10(wheel)
flag{musl_crypt_r3turns_st4r}
```

对照组（应该失败）：

```bash
# 短密码
./verify.sh 127.0.0.1 2222 short

# 或者把 root 的 shadow 改成 ! 再试
docker exec musl-ssh-bypass sed -i 's/^root:[^:]*:/root:!:/' /etc/shadow
docker restart musl-ssh-bypass
./verify.sh 127.0.0.1 2222      # 期望 failed
```

## 排查

| 现象 | 原因 |
|---|---|
| 两次都失败 | 机器上没有真实哈希账户可借盐；给任一账户 `passwd` 设个密码再试 |
| 第二次仍失败 | 检查 `PermitRootLogin`（`sshd -T \| grep permitrootlogin`） |
| 直接失败、日志有 `not allowed because shell` | 目标账户 shell 是 nologin，换账户或改 shell |
| `sshd -T` 无 `usepam` 输出 | 说明编译时就没启用 PAM，符合条件 |

## 修复

1. 升级到 OpenSSH 10.6p2 或发行版安全更新。
2. 无法升级时：`PasswordAuthentication no`，只留公钥。
3. 应急：把 shadow 里的 `*` 改成 `!`（`!` 不匹配 `crypt()` 的返回值）。
   改完用密钥登录一次确认没影响业务。
4. `PermitRootLogin` 设为 `prohibit-password` 或 `no`。

## 许可

仅用于授权的安全测试与教学。
