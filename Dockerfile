FROM alpine AS base
RUN apk add openssh-server

FROM base AS ca
RUN ssh-keygen -f /etc/ssh/ca -N ''

FROM base AS server_pre
RUN ssh-keygen -A

FROM ca AS server_sign
COPY --from=server_pre /etc/ssh/ssh_host* /tmp/
ARG SRV_HOST=srv1
RUN ssh-keygen -s /etc/ssh/ca \
     -I "$SRV_HOST host key" \
     -n "$SRV_HOST" \
     -V -5m:+3650d \
     -h \
     $(ls /tmp/ssh_host_*.pub)
RUN ls -ltra /tmp

FROM server_pre AS server
COPY --from=server_sign /tmp/ssh_host_*-cert.pub /etc/ssh/
RUN for f in /etc/ssh/ssh_host*_key-cert.pub; do echo "HostCertificate $f" >>/etc/ssh/sshd_config ; done

