FROM golang:1.23.6 AS build

## (DL3008)Ignore lint error about apt pinned packages, as we always want the latest version of these tools
## and the risk of a breaking behavior is evaluated as low
# hadolint ignore=DL3008
RUN apt-get -qq update && \
  apt-get install --no-install-recommends -y libgeoip-dev tar curl ca-certificates git unzip zlib1g-dev && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 955a8b2e1aacea1cae06396a64afbb531ceb36d4 introduced go modules (for Go >= 1.11) and commited the generated code from protoc
# v0.5.1 tag is a bit older (but without these 2 majors elements): https://github.com/etix/mirrorbits/commit/e83e56ac6496a3643d18a731324bd266f75f7b32 commit
# Diff: https://github.com/etix/mirrorbits/compare/e83e56ac6496a3643d18a731324bd266f75f7b32..955a8b2e1aacea1cae06396a64afbb531ceb36d4
ARG mirrorbits_version=955a8b2e1aacea1cae06396a64afbb531ceb36d4

WORKDIR "/mirrorbits"

# hadolint ignore=DL3003
RUN git clone https://github.com/etix/mirrorbits ./ && \
  git checkout "${mirrorbits_version}"

# Do not call parent target (dependencies are vendorized) but we still want the proper LDFLAGS
RUN sed -i 's/^build:.*/build:/g' Makefile && \
  make build

ARG tini_version=v0.19.0
RUN curl --silent --show-error --output ./tini --location \
  "https://github.com/krallin/tini/releases/download/${tini_version}/tini-$(dpkg --print-architecture)" && \
  chmod a+x ./tini

FROM debian:stable-slim AS mirrorbits

# Repeat ARGS for labels
ARG tini_version=v0.19.0
ARG mirrorbits_version=955a8b2e1aacea1cae06396a64afbb531ceb36d4

## (DL3008)Ignore lint error about apt pinned packages, as we always want the latest version of these tools
## and the risk of a breaking behavior is evaluated as low
# hadolint ignore=DL3008
RUN apt-get update && \
  apt-get install --no-install-recommends -y ftp rsync ca-certificates vim-tiny && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN useradd -M mirrorbits && \
  mkdir /etc/mirrorbits  && \
  mkdir /usr/share/mirrorbits/ && \
  mkdir /srv/repo && \
  mkdir /run/mirrorbits && \
  mkdir /var/log/mirrorbits && \
  ln -s /dev/stdout /var/log/mirrorbits/downloads.log && \
  chown mirrorbits -R /usr/share/mirrorbits/ && \
  chown mirrorbits /run/mirrorbits && \
  chown mirrorbits /var/log/mirrorbits && \
  chown mirrorbits /srv/repo

USER mirrorbits

COPY config/mirrorbits.conf /etc/mirrorbits/mirrorbits.conf

COPY --from=build /mirrorbits/tini /bin/tini
COPY --from=build /mirrorbits/bin/mirrorbits /usr/bin/mirrorbits
COPY --from=build /mirrorbits/templates /usr/share/mirrorbits/templates

LABEL \
  io.jenkins-infra.tools="mirrorbits,tini" \
  io.jenkins-infra.tools.mirrorbits.version="${mirrorbits_version}" \
  io.jenkins-infra.tools.tini.version="${tini_version}" \
  repository="https://github.com/jenkins-infra/docker-mirrorbits"

EXPOSE 8080 3390

ENTRYPOINT [ "/bin/tini","--" ]

CMD [ "/usr/bin/mirrorbits","daemon","--config","/etc/mirrorbits/mirrorbits.conf" ]
