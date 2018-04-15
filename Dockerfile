FROM ubuntu:16.04

ARG VERSION=master
ENV VERSION=${VERSION}

LABEL maintainer="jayderfranca@gmail.com"
LABEL source="https://github.com/niobio-cash/niobio-node-daemon.git"
LABEL version="${VERSION}"

ADD ./entrypoint.sh /

RUN apt-get update \
 && apt-get -y install git build-essential cmake libboost-all-dev \
 && mkdir /niobio \
 && git clone --branch ${VERSION} --single-branch https://github.com/niobio-cash/niobio-node-daemon.git /tmp/daemon \
 && mkdir /tmp/daemon/build \
 && cd /tmp/daemon/build \
 && cmake .. \
 && make -j2 \
 && apt-get -y purge git build-essential cmake \
 && apt-get -y autoremove --purge \
 && cp --preserve src/walletd src/niobiod /usr/bin/. \
 && cd / \
 && rm -fR /tmp/daemon \
 && chmod +x /entrypoint.sh

WORKDIR /niobio

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
