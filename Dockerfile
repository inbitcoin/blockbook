FROM debian:stretch

ENV LANG="C.UTF-8" USER="blockbook" APP="/opt/coins/blockbook/bitcoin/"

RUN adduser --shell /bin/bash --disabled-login --gecos "user" ${USER}

COPY build/*.deb /tmp/

RUN echo 'deb http://ftp.debian.org/debian stretch-backports main' >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y supervisor && \
    apt-get install -y /tmp/*.deb && \
    apt-get -t stretch-backports install -y rocksdb-tools && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY supervisor.conf ${APP}/supervisor.conf

WORKDIR ${APP}

EXPOSE 9030 9130

ENV DB_STATS_PERIOD=0 DEBUG=false WORKERS=8
CMD ["/usr/bin/supervisord", "-c", "/opt/coins/blockbook/bitcoin/supervisor.conf"]
