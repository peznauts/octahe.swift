ARG VERSION=5.2

FROM swift:${VERSION} as BUILD

WORKDIR /opt/octahe.swift

RUN apt-get update && apt-get -yq install libssl-dev

COPY . /opt/octahe.swift

RUN swift build --configuration release -Xswiftc -g && \
    cp /opt/octahe.swift/.build/release/octahe /usr/local/bin/ && \
    rm -rf /opt/octahe.swift

FROM swift:${VERSION}-slim

RUN apt-get update && apt-get -yq install openssl

COPY --from=BUILD /usr/local/bin/octahe /usr/local/bin/octahe

USER 1001

CMD /usr/local/bin/octahe
