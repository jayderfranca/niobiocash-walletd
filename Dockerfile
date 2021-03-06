FROM ubuntu:16.04

ARG VERSION=master
ENV VERSION=${VERSION}

LABEL maintainer="Jayder França <jayderfranca@gmail.com>"
LABEL source="https://github.com/niobio-cash/niobio-node-daemon.git"
LABEL version="${VERSION}"

ADD ./entrypoint.sh /

RUN apt-get update \
 && apt-get -y install git build-essential cmake libboost-all-dev python-pip \
 && mkdir /niobio \
 && git clone --branch ${VERSION} --single-branch https://github.com/niobio-cash/niobio-node-daemon.git /tmp/daemon \
 && mkdir /tmp/daemon/build \
 && cd /tmp/daemon/build \
 && cmake .. \
 && make -j2 \
 && pip install supervisor \
 && apt-get -y purge git build-essential cmake \
 && apt-get -y autoremove --purge \
 && cp --preserve src/walletd src/niobiod /usr/bin/. \
 && cd / \
 && rm -fR /tmp/daemon \
 && chmod +x /entrypoint.sh

VOLUME /niobio

EXPOSE 20264/tcp
EXPOSE 30264/tcp
EXPOSE 40264/tcp

ENTRYPOINT ["/entrypoint.sh"]
