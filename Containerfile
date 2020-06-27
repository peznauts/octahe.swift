ARG VERSION=5.2

FROM swift:${VERSION}-centos8

WORKDIR /opt/octahe.swift

RUN dnf -y install libssh2-devel openssl-devel && \
    mkdir -p /root/.ssh/ && chmod 700 /root/.ssh && \
    ssh-keyscan github.com >> /root/.ssh/known_hosts && \
    git clone https://github.com/peznauts/octahe.swift /opt/octahe.swift && \
    export LDFLAGS="-L/usr/lib64" && \
    export CPPFLAGS="-I/usr/include" && \
    export PKG_CONFIG_PATH="/usr/lib64/pkgconfig" && \
    swift build --configuration release -Xswiftc -g && \
    cp /opt/octahe.swift/.build/release/octahe /usr/local/bin/ && \
    rm -rf /opt/octahe.swift
