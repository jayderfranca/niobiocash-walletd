FROM ubuntu:16.04

ADD ./entrypoint.sh /

COPY ./daemon /tmp/daemon/.

RUN apt-get -qq update && \
    apt-get -qq install build-essential cmake libboost-all-dev > /dev/null && \
    mkdir /niobio && \
    mkdir /tmp/daemon/build && \
    cd /tmp/daemon/build && \
    cmake .. && \
    make -j4 && \
    apt-get -qq -y purge build-essential cmake > /dev/null && \
    apt-get -qq -y autoremove --purge > /dev/null && \
    cp --preserve src/walletd /usr/bin/. && \
    cd / && \
    rm -fR /tmp/daemon && \
    chmod +x /entrypoint.sh

WORKDIR /niobio

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
