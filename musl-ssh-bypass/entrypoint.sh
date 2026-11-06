#!/bin/sh
# 容器入口：写 flag 后前台运行 sshd
# 平台部署时会注入 LAB_FLAG（动态 flag），本地运行时用镜像内置的静态 flag
set -e

if [ -n "$LAB_FLAG" ]; then
    printf '%s\n' "$LAB_FLAG" > /root/flag.txt
else
    echo 'flag{musl_crypt_r3turns_st4r}' > /root/flag.txt
fi
chmod 600 /root/flag.txt

mkdir -p /run/sshd
exec /usr/sbin/sshd -D -e
