FROM golang:1.12.4-alpine3.9
RUN apk add --update --no-cache build-base git
RUN apk add bash gmp libcrypto1.1 libssl1.1               # For Herumi

#Download the go dependencies
ENV CGO_CFLAGS="-I$GOPATH/src/github.com/herumi/bls/include -I$GOPATH/src/github.com/herumi/mcl/include"
ENV CGO_LDFLAGS="-L$GOPATH/src/github.com/herumi/bls/lib -L$GOPATH/src/github.com/herumi/mcl/lib"
ENV GO111MODULE=on

RUN apk add gmp gmp-dev openssl-dev && \
    cd /tmp && \
    wget -O - https://github.com/herumi/mcl/archive/v0.98.tar.gz | tar xz && \
    wget -O - https://github.com/herumi/bls/archive/master.tar.gz | tar xz && \
    mv mcl* mcl && \
    mv bls* bls && \
    make -C mcl -j $(nproc) lib/libmclbn256.so install && \
    cp mcl/lib/libmclbn256.so /usr/local/lib && \
    make -C bls -j $(nproc) install && \
    rm -R /tmp/mcl && \
    rm -R /tmp/bls

ENV BUILD_DIR=/0chain/go/src/magicBlock
ENV GOPATH=$GOPATH:$SRC_DIR/go

WORKDIR $BUILD_DIR

COPY ./  ./