FROM ubuntu:18.04
# Originally based on ubuntu:16.04.
# RhodeCode provides the relevant binaries so the actual OS
# version shouldn't make much of a difference.
#
# These are Ubuntu's current LTS:
#   Version   Supported until    Security support until
#   ----------------------------------------------------
#    16.04        2021-04               2024-04
#    18.04        2023-04               2028-04
#    20.04        2025-04               2030-04

LABEL maintainer="Toni Corvera <outlyer@gmail.com>"
# Standard(ish) labels/annotations <https://github.com/opencontainers/image-spec/blob/master/annotations.md>
LABEL org.opencontainers.image.name="Unofficial RhodeCode CE Dockerized"
LABEL org.opencontainers.image.description="RhodeCode Community Edition is an open\
source Source Code Management server with support for Git, Mercurial and Subversion\
(Subversion support is not -yet- enabled in this image, though)"
LABEL org.opencontainers.image.url="https://hub.docker.com/repository/docker/outlyernet/rhodecode-ce"
LABEL org.opencontainers.image.source="https://github.com/outlyer-net/docker-rhodecode-ce"
#LABEL org.opencontainers.image.licenses= # TODO
#LABEL org.opencontainers.image.version= # TODO

# ARG RCC_VERSION=1.24.2
ARG RC_VERSION=4.22.0
ARG ARCH=x86_64
# Allow overriding the manifest URL (for development purposes)
ARG RHODECODE_MANIFEST_URL="https://dls.rhodecode.com/linux/MANIFEST"
# TODO: Can this be downloaded more transparently?
# XXX: This URL is also used in the automation recipes <https://code.rhodecode.com/rhodecode-automation-ce/files/4ea5dcd54ba64245b0e1fea29b9ba29667d366b3/provisioning/ansible/provision_rhodecode_ce_vm.yaml>
ARG RHODECODE_INSTALLER_URL="https://dls-eu.rhodecode.com/dls/NzA2MjdhN2E2ODYxNzY2NzZjNDA2NTc1NjI3MTcyNzA2MjcxNzIyZTcwNjI3YQ==/rhodecode-control/latest-linux-ce"

ENV RHODECODE_USER=admin
ENV RHODECODE_USER_PASS=secret
ENV RHODECODE_USER_EMAIL=rhodecode-support@example.com
# NOTE unattended installs only support sqlite (but can be reconfigured later)
ENV RHODECODE_DB=sqlite
ENV RHODECODE_REPO_DIR=/home/rhodecode/repos
ENV RHODECODE_VCS_PORT=3690
ENV RHODECODE_HTTP_PORT=8080
ENV RHODECODE_HOST=0.0.0.0

RUN apt-get update \
        && DEBIAN_FRONTEND=noninteractive \
                apt-get -y install --no-install-recommends \
                    bzip2 \
                    ca-certificates \
                    locales \
                    python \
                    sudo \
                    supervisor \
                    tzdata \
                    wget

RUN useradd --create-home --shell /bin/bash rhodecode \
        && sudo adduser rhodecode sudo \
        && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
        && locale-gen en_US.UTF-8 \
        && update-locale

COPY container/healthcheck.sh /healthcheck

USER rhodecode

COPY build/setup-rhodecode.bash /tmp
RUN bash /tmp/setup-rhodecode.bash

COPY container/reset_image.sh /home/rhodecode/
# Make a backup of the initial data, so that it can be easily restored
RUN mkdir /home/rhodecode/.rccontrol.dist \
        && cp -rvpP /home/rhodecode/.rccontrol/community-1 /home/rhodecode/.rccontrol.dist/community-1 \
        && cp -rvpP /home/rhodecode/.rccontrol/vcsserver-1 /home/rhodecode/.rccontrol.dist/vcsserver-1

# NOTE: Declared VOLUME's will be created at the point they're listed,
#       Must not create them early to avoid permission issues
VOLUME ${RHODECODE_REPO_DIR}
# These will contain RhodeCode installed files (which are much needed too)
#  By declaring them as volumes, if a Docker volume is mounted over them their contents
#  will be copied. However, that apparently doesn't apply to bind mounts.
VOLUME /home/rhodecode/.rccontrol/community-1
VOLUME /home/rhodecode/.rccontrol/vcsserver-1

# Declared volumes are created as root, but must be writable by rhodecode
RUN chown rhodecode.rhodecode \
        /home/rhodecode/.rccontrol/community-1 \
        /home/rhodecode/.rccontrol/vcsserver-1

HEALTHCHECK CMD [ "/healthcheck" ]

WORKDIR /home/rhodecode
COPY container/entrypoint.sh /entrypoint

CMD [ "/entrypoint" ]
