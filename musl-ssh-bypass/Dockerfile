# syntax=docker/dockerfile:1
FROM alpine:3.22

# 固定版本，避免上游更新后行为漂移
ARG OPENSSH_VER=10.5p1

RUN apk add --no-cache build-base zlib-dev openssl-dev linux-headers curl

# 编译 OpenSSH：关键在 --without-pam —— 只有非 PAM 路径才会走到有问题的比较逻辑
RUN set -eux; \
    curl -fsSL "https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-${OPENSSH_VER}.tar.gz" \
      -o /tmp/openssh.tar.gz; \
    cd /tmp; \
    tar xzf openssh.tar.gz; \
    cd "openssh-${OPENSSH_VER}"; \
    ./configure \
      --prefix=/usr \
      --sysconfdir=/etc/ssh \
      --with-privsep-path=/var/empty \
      --without-pam \
      --with-ssl-dir=/usr; \
    make -j"$(nproc)" > /dev/null; \
    make install; \
    cp sshd_config /etc/ssh/sshd_config; \
    cd /; rm -rf /tmp/openssh*; \
    ssh-keygen -A

# 两个账户：
#   seed —— 持真实 $6$ 哈希，pick_salt() 靠它借盐（缺了它漏洞不成立）
#   root —— shadow 密码字段改成 *，且允许密码登录
RUN set -eux; \
    adduser -D -s /bin/sh seed; \
    echo 'seed:Seed@2026' | chpasswd; \
    echo 'root:Root@2026' | chpasswd; \
    sed -i 's/^root:[^:]*:/root:*:/' /etc/shadow; \
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config; \
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config; \
    mkdir -p /run/sshd

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22

# 前台运行，容器不退出
ENTRYPOINT ["/entrypoint.sh"]
