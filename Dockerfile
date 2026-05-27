# syntax=docker/dockerfile:1
ARG ALPINE_VERSION
FROM alpine:${ALPINE_VERSION} AS build

ARG MAINTAINER="xSavior-of-God <micga68@gmail.com>"
ARG ALPINE_VERSION
ARG MODSEC_VER
ARG NGINX_VER
ARG MODSEC_NGINX_VER
ARG GEOIP2_VER
ARG HEADERS_MORE_VER
ARG OWASP_CRS_VER
ARG GEOIP_DB_VER
ARG GEOIP_DB_MONTH

RUN apk update && apk add alpine-sdk git \
    && adduser -D builder \
    && addgroup builder abuild \
    && mkdir -p /home/builder/.abuild /home/builder/packages

COPY keys/packager.rsa.pub /etc/apk/keys/
COPY keys/packager.rsa.pub /home/builder/.abuild/packager.rsa.pub

RUN printf 'PACKAGER_PRIVKEY=/home/builder/.abuild/packager.rsa\nPACKAGER="%s"\n' \
        "${MAINTAINER}" > /home/builder/.abuild/abuild.conf \
    && chown -R builder:builder /home/builder

COPY apkbuilds/ /build/

# ===== 1. libmodsecurity =====
RUN sed -i \
    -e "s|@@MAINTAINER@@|${MAINTAINER}|g" \
    -e "s|@@MODSEC_VER@@|${MODSEC_VER}|g" \
    /build/libmodsecurity/APKBUILD

RUN --mount=type=secret,id=signing_key,target=/home/builder/.abuild/packager.rsa,mode=0444 \
    cd /build/libmodsecurity \
    && chown -R builder:builder . \
    && su builder -c "abuild checksum" \
    && su builder -c "abuild -r"

RUN apk add --allow-untrusted /home/builder/packages/*/x86_64/libmodsecurity-*.apk

RUN apk add brotli-dev build-base gd-dev git libmaxminddb-dev libxml2-dev \
    libxslt-dev linux-headers openssl-dev pcre2-dev perl-dev perl-utils zlib-dev

# ===== 2. nginx-modsec =====
RUN sed -i \
    -e "s|@@MAINTAINER@@|${MAINTAINER}|g" \
    -e "s|@@NGINX_VER@@|${NGINX_VER}|g" \
    -e "s|@@MODSEC_NGINX_VER@@|${MODSEC_NGINX_VER}|g" \
    -e "s|@@GEOIP2_VER@@|${GEOIP2_VER}|g" \
    -e "s|@@HEADERS_MORE_VER@@|${HEADERS_MORE_VER}|g" \
    /build/nginx-modsec/APKBUILD

RUN --mount=type=secret,id=signing_key,target=/home/builder/.abuild/packager.rsa,mode=0444 \
    cd /build/nginx-modsec \
    && chown -R builder:builder . \
    && su builder -c "abuild checksum" \
    && su builder -c "abuild -r -d"

# ===== 3. owasp-crs =====
RUN sed -i \
    -e "s|@@MAINTAINER@@|${MAINTAINER}|g" \
    -e "s|@@OWASP_CRS_VER@@|${OWASP_CRS_VER}|g" \
    /build/owasp-crs/APKBUILD

RUN --mount=type=secret,id=signing_key,target=/home/builder/.abuild/packager.rsa,mode=0444 \
    cd /build/owasp-crs \
    && chown -R builder:builder . \
    && su builder -c "abuild checksum" \
    && su builder -c "abuild -r"

# ===== 4. nginx-geoip-db =====
RUN sed -i \
    -e "s|@@MAINTAINER@@|${MAINTAINER}|g" \
    -e "s|@@GEOIP_DB_VER@@|${GEOIP_DB_VER}|g" \
    -e "s|@@GEOIP_DB_MONTH@@|${GEOIP_DB_MONTH}|g" \
    /build/nginx-geoip-db/APKBUILD

RUN --mount=type=secret,id=signing_key,target=/home/builder/.abuild/packager.rsa,mode=0444 \
    cd /build/nginx-geoip-db \
    && chown -R builder:builder . \
    && su builder -c "abuild checksum" \
    && su builder -c "abuild -r"

# ===== Assemble APK repository =====
RUN --mount=type=secret,id=signing_key <<'ASSEMBLE'
mkdir -p /repo/v${ALPINE_VERSION}/x86_64
cp /home/builder/packages/*/x86_64/*.apk /repo/v${ALPINE_VERSION}/x86_64/ 2>/dev/null || true
cp /home/builder/packages/*/noarch/*.apk /repo/v${ALPINE_VERSION}/x86_64/ 2>/dev/null || true
cd /repo/v${ALPINE_VERSION}/x86_64
apk index -o APKINDEX.unsigned.tar.gz *.apk
cp APKINDEX.unsigned.tar.gz APKINDEX.tar.gz
abuild-sign -k /run/secrets/signing_key APKINDEX.tar.gz
rm -f APKINDEX.unsigned.tar.gz
ASSEMBLE

FROM scratch AS output
COPY --from=build /repo/ /
