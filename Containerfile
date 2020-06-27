ARG VERSION=5.2

FROM swift:${VERSION}-centos8

RUN dnf -y install libssh2-devel openssl-devel

RUN mkdir -p /root/.ssh/ && chmod 700 /root/.ssh

RUN ssh-keyscan github.com >> /root/.ssh/known_hosts

RUN git clone https://github.com/peznauts/octahe.swift /opt/octahe.swift

WORKDIR /opt/octahe.swift

RUN export LDFLAGS="-L/usr/lib64" && \
    export CPPFLAGS="-I/usr/include" && \
    export PKG_CONFIG_PATH="/usr/lib64/pkgconfig" && \
    swift build \
    --configuration release \
    --jobs 4 \
    -Xswiftc \
    -g
