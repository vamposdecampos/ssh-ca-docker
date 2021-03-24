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
COPY --from=ca /etc/ssh/ca.pub /etc/ssh/
COPY --from=server_sign /tmp/ssh_host_*-cert.pub /etc/ssh/
RUN \
	for f in /etc/ssh/ssh_host*_key-cert.pub; do echo "HostCertificate $f" >>/etc/ssh/sshd_config ; done && \
	echo "###AuthorizedPrincipalsFile %h/.ssh/authorized_principals" >>/etc/ssh/sshd_config && \
	echo "TrustedUserCAKeys /etc/ssh/ca.pub" >>/etc/ssh/sshd_config && \
	adduser -D user1 && \
	adduser -D user2 && \
	echo user1:insecure1 | chpasswd && \
	echo user2:insecure2 | chpasswd && \
	echo root:insecure0 | chpasswd
#USER user1
#RUN mkdir -p ~/.ssh && echo principal1 > ~/.ssh/authorized_principals



FROM base AS client
RUN apk add openssh-client
COPY --from=ca /etc/ssh/ca.pub /etc/ssh/
RUN echo "@cert-authority * $(cat /etc/ssh/ca.pub)" >>/etc/ssh/ssh_known_hosts
RUN adduser -D client1
USER client1
RUN ssh-keygen -N '' -t rsa -f ~/.ssh/id_rsa
# hackity hack (snarf CA private key)
USER root
COPY --from=ca /etc/ssh/ca /etc/ssh/
RUN ssh-keygen -s /etc/ssh/ca \
    -I "signed client1 user key" \
    -n user1,user2,principal1 \
    -V -5m:+3650d \
    ~client1/.ssh/id_rsa.pub
USER client1
