FROM ubuntu:16.04 AS builder

ARG VERSION

RUN apt update \
 && apt -y install git build-essential cmake libboost-all-dev python-pip \
 && git clone --branch ${VERSION} --single-branch https://github.com/niobio-cash-classic/niobio-node-daemon.git /tmp/daemon \
 && mkdir /tmp/daemon/build \
 && cd /tmp/daemon/build \
 && cmake .. \
 && make -j2

FROM ubuntu:16.04

ARG VERSION
ENV VERSION=${VERSION}

LABEL maintainer="Jayder França <jayderfranca@gmail.com>"
LABEL source="https://github.com/niobio-cash-classic/niobio-node-daemon.git"
LABEL version="${VERSION}"

ADD ./entrypoint.sh /
RUN chmod +x /entrypoint.sh

RUN mkdir /niobio

RUN apt update \
 && apt -y install libboost-all-dev python-pip

RUN pip install supervisor

COPY --from=builder /tmp/daemon/build/src/niobiod /usr/bin/.
COPY --from=builder /tmp/daemon/build/src/walletd /usr/bin/.

VOLUME /niobio

EXPOSE 20264/tcp
EXPOSE 30264/tcp
EXPOSE 40264/tcp

ENTRYPOINT ["/entrypoint.sh"]
