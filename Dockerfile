FROM alpine:latest as builder

ARG NSD_VERSION=4.9.1
ARG SHA256_HASH="a6c23a53ee8111fa71e77b7565d1b8f486ea695770816585fbddf14e4367e6df"


RUN apk add --no-cache \
      bash \
      curl \
      build-base \
      libevent-dev \
      openssl-dev \
      ca-certificates

SHELL [ "/bin/bash", "-o", "pipefail", "-c" ]

WORKDIR /tmp
RUN \
   curl -OO https://www.nlnetlabs.nl/downloads/nsd/nsd-${NSD_VERSION}.tar.gz && \
   echo "Verifying SHA256 of nsd-${NSD_VERSION}.tar.gz..." && \
   CHECKSUM=$(sha256sum nsd-${NSD_VERSION}.tar.gz | awk '{print $1}') && \
   if [ "${CHECKSUM}" == "${SHA256_HASH}" ]; then echo "SHA256 is correct"; else echo "ERROR: SHA256 does not match!" && exit 1; fi

RUN echo "Extracting nsd-${NSD_VERSION}.tar.gz..." && \
    tar -xzf "nsd-${NSD_VERSION}.tar.gz"
WORKDIR /tmp/nsd-${NSD_VERSION}

RUN ./configure \
    CFLAGS="-O2 -flto -fPIE -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=2 -fstack-protector-strong \
            -Wformat -Werror=format-security" \
    LDFLAGS="-Wl,-z,now -Wl,-z,relro" && \
    make && \
    make install DESTDIR=/builder

# Temporary fix
RUN cd /builder && tar -czvf /builder.tar.gz *


FROM alpine:latest

LABEL Maintainer "The-Kube-Way (https://github.com/The-Kube-Way/nsd)"

RUN apk add --no-cache \
   ldns \
   ldns-tools \
   libevent \
   openssl \
   tini

# COPY --from=builder /builder /
# Temporary fix as COPY command above does not work with docker buildx
COPY --from=builder /builder.tar.gz /
RUN tar -C / -xvf /builder.tar.gz && rm /builder.tar.gz

COPY bin /usr/local/bin

ENV UID=991 GID=991

EXPOSE 53 53/udp

CMD ["start_nsd.sh"]
