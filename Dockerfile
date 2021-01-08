FROM debian:stable-slim AS mirrorbits

ENV MIRRORBIT_VERSION=v0.5.1

RUN \
  apt-get update && \
  apt-get install -y tar curl && \
  apt-get clean && \
  find /var/lib/apt/lists -type f -delete

RUN \
  mkdir /mirrorbits && \
  curl -L https://github.com/etix/mirrorbits/releases/download/${MIRRORBIT_VERSION}/mirrorbits-${MIRRORBIT_VERSION}.tar.gz -O && \
  tar xvzf /mirrorbits-${MIRRORBIT_VERSION}.tar.gz -C / && \
  rm /mirrorbits-${MIRRORBIT_VERSION}.tar.gz

FROM debian:stable-slim

EXPOSE 8080

ENV TINI_VERSION=v0.19.0

ENV MIRRORBIT_VERSION=v0.5.1

LABEL MAINTAINER="https://github.com/olblak"

LABEL MIRRORBIT_VERSION=v0.5.1

LABEL TINI_VERSION=v0.19.0

LABEL repository="https://github.com/olblak/mirrorbits"

ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /bin/tini

RUN chmod +x /bin/tini

RUN \
  apt-get update && \
  apt-get install -y ftp rsync ca-certificates && \
  apt-get clean && \
  find /var/lib/apt/lists -type f -delete

RUN \
  useradd -M mirrorbits && \
  mkdir /etc/mirrorbits  && \
  mkdir /usr/share/mirrorbits/ && \
  mkdir /srv/repo && \
  mkdir /run/mirrorbits && \
  mkdir /var/log/mirrorbits && \
  chown mirrorbits -R /usr/share/mirrorbits/ && \
  chown mirrorbits /run/mirrorbits && \
  chown mirrorbits /var/log/mirrorbits && \
  chown mirrorbits /srv/repo

USER mirrorbits

COPY config/mirrorbits.conf /etc/mirrorbits/mirrorbits.conf

COPY --from=mirrorbits  /mirrorbits/mirrorbits /usr/bin/mirrorbits

COPY --from=mirrorbits  /mirrorbits/templates /usr/share/mirrorbits/templates

ENTRYPOINT ["/bin/tini", "--"]

CMD [ "/usr/bin/mirrorbits","daemon","--config","/etc/mirrorbits/mirrorbits.conf"]

