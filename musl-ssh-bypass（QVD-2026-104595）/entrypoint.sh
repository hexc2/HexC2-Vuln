#!/bin/sh
# 平台若注入 LAB_FLAG（动态 flag），以它为准；否则用镜像内置的静态 flag
if [ -n "$LAB_FLAG" ]; then
    printf '%s\n' "$LAB_FLAG" > /root/flag.txt
else
    echo 'flag{musl_crypt_r3turns_st4r}' > /root/flag.txt
fi
chmod 600 /root/flag.txt

mkdir -p /run/sshd /run/nginx

# 80：官网（信息收集入口）；22：sshd（真正的攻击面）
nginx

exec /usr/sbin/sshd -D -e
