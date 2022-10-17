
# bump: libmodplug /LIBMODPLUG_VERSION=([\d.]+)/ fetch:https://sourceforge.net/projects/modplug-xmms/files/|/libmodplug-([\d.]+).tar.gz/
# bump: libmodplug after ./hashupdate Dockerfile LIBMODPLUG $LATEST
# bump: libmodplug link "NEWS" https://sourceforge.net/p/modplug-xmms/git/ci/master/tree/libmodplug/NEWS
ARG LIBMODPLUG_VERSION=0.8.9.0
ARG LIBMODPLUG_URL="https://downloads.sourceforge.net/modplug-xmms/libmodplug-$LIBMODPLUG_VERSION.tar.gz"
ARG LIBMODPLUG_SHA256=457ca5a6c179656d66c01505c0d95fafaead4329b9dbaa0f997d00a3508ad9de

# Must be specified
ARG ALPINE_VERSION

FROM alpine:${ALPINE_VERSION} AS base

FROM base AS download
ARG LIBMODPLUG_URL
ARG LIBMODPLUG_SHA256
ARG WGET_OPTS="--retry-on-host-error --retry-on-http-error=429,500,502,503 -nv"
WORKDIR /tmp
RUN \
  apk add --no-cache --virtual download \
    coreutils wget tar && \
  wget $WGET_OPTS -O libmodplug.tar.gz "$LIBMODPLUG_URL" && \
  echo "$LIBMODPLUG_SHA256  libmodplug.tar.gz" | sha256sum --status -c - && \
  mkdir libmodplug && \
  tar xf libmodplug.tar.gz -C libmodplug --strip-components=1 && \
  rm libmodplug.tar.gz && \
  apk del download

FROM base AS build
COPY --from=download /tmp/libmodplug/ /tmp/libmodplug/
WORKDIR /tmp/libmodplug
RUN \
  apk add --no-cache --virtual build \
    build-base pkgconf && \
  ./configure --disable-shared --enable-static && \
  make -j$(nproc) install && \
  # Sanity tests
  pkg-config --exists --modversion --path libmodplug && \
  ar -t /usr/local/lib/libmodplug.a && \
  readelf -h /usr/local/lib/libmodplug.a && \
  # Cleanup
  apk del build

FROM scratch
ARG LIBMODPLUG_VERSION
COPY --from=build /usr/local/lib/pkgconfig/libmodplug.pc /usr/local/lib/pkgconfig/libmodplug.pc
COPY --from=build /usr/local/lib/libmodplug.a /usr/local/lib/libmodplug.a
COPY --from=build /usr/local/include/libmodplug/ /usr/local/include/libmodplug/
