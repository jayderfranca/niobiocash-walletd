FROM ubuntu:16.04

ADD ./entrypoint.sh /

RUN apt-get -qq update && \
    apt-get -qq install git build-essential cmake libboost-all-dev > /dev/null && \
    mkdir /niobio && \
    git clone https://github.com/niobio-cash/niobio-node-daemon.git /tmp/daemon && \
    mkdir /tmp/daemon/build && \
    cd /tmp/daemon/build && \
    cmake .. && \
    make -j2 && \
    apt-get -qq -y purge git build-essential cmake > /dev/null && \
    apt-get -qq -y autoremove --purge > /dev/null && \
    cp --preserve src/walletd /usr/bin/. && \
    cd / && \
    rm -fR /tmp/daemon && \
    chmod +x /entrypoint.sh

WORKDIR /niobio

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
