ARG VERSION=5.2

FROM swift:${VERSION}-centos8 as BUILD

WORKDIR /opt/octahe.swift

RUN dnf -y install libssh2-devel openssl-devel && \
    dnf clean all && \
  	rm -rf /var/cache/yum

COPY . /opt/octahe.swift

RUN export LDFLAGS="-L/usr/lib64" && \
    export CPPFLAGS="-I/usr/include" && \
    export PKG_CONFIG_PATH="/usr/lib64/pkgconfig" && \
    swift build --configuration release -Xswiftc -g && \
    cp /opt/octahe.swift/.build/release/octahe /usr/local/bin/ && \
    rm -rf /opt/octahe.swift

FROM swift:${VERSION}-slim

RUN apt-get update && apt-get -yq install libssh2-1 openssl

COPY --from=BUILD /usr/local/bin/octahe /usr/local/bin/octahe

USER 1001

CMD /usr/local/bin/octahe
