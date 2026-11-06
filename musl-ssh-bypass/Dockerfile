FROM alpine:3.22

RUN apk add --no-cache build-base zlib-dev openssl-dev linux-headers nginx

COPY openssh-10.5p1.tar.gz /tmp/
RUN cd /tmp && tar xzf openssh-10.5p1.tar.gz && cd openssh-10.5p1 \
 && ./configure --prefix=/usr --sysconfdir=/etc/ssh \
      --with-privsep-path=/var/empty --without-pam --with-ssl-dir=/usr \
 && make -j4 >/dev/null 2>&1 && make install \
 && cp /tmp/openssh-10.5p1/sshd_config /etc/ssh/sshd_config \
 && ssh-keygen -A \
 && adduser -D -s /bin/sh seed && echo 'seed:Seed@2026' | chpasswd \
 && echo 'root:Root@2026' | chpasswd \
 && sed -i 's/^root:[^:]*:/root:*:/' /etc/shadow \
 && sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
 && sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
 && mkdir -p /run/sshd && rm -rf /tmp/openssh-10.5p1 /tmp/openssh-10.5p1.tar.gz

# 80 端口的官网页面（静态）
COPY site/index.html /usr/share/nginx/html/index.html
COPY site/default.conf /etc/nginx/http.d/default.conf

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22 80
ENTRYPOINT ["/entrypoint.sh"]
