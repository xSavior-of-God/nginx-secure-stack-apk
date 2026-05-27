#!/bin/sh

PAUSE=false
NO_CACHE=""
for arg in "$@"; do
    [ "$arg" = "--pause" ] && PAUSE=true
    [ "$arg" = "--no-cache" ] && NO_CACHE="--no-cache"
done

pause_exit() {
    code=$?
    if [ "$PAUSE" = true ]; then
        echo ""
        printf "Press Enter to exit..."
        read _
    fi
    exit $code
}
trap pause_exit EXIT

set -eo pipefail

CONFIG="versions.yml"

read_ver() {
    sed -n "/^  $1:/,/^  [a-z]/{/version:/{s/.*version: \"\(.*\)\"/\1/p;q;}}" "$CONFIG"
}

ALPINE=$(sed -n 's/^alpine: "\(.*\)"/\1/p' "$CONFIG")

if [ -z "$ALPINE" ]; then
    echo "ERROR: alpine version not set in $CONFIG"
    exit 1
fi

if [ ! -f keys/packager.rsa ]; then
    echo "ERROR: No signing key found. Run ./keygen.sh first."
    exit 1
fi

MODSEC_VER=$(read_ver libmodsecurity)
NGINX_VER=$(read_ver nginx)
MODSEC_NGINX_VER=$(read_ver modsecurity-nginx)
GEOIP2_VER=$(read_ver geoip2)
HEADERS_MORE_VER=$(read_ver headers-more)
OWASP_CRS_VER=$(read_ver owasp-crs)
GEOIP_DB_VER=$(read_ver geoip-db)
GEOIP_DB_MONTH=$(sed -n '/^  geoip-db:/,/^  [a-z]/{/month:/{s/.*month: "\(.*\)"/\1/p;q;}}' "$CONFIG")

echo "=== nginx-secure-stack-apk: Building APK packages (Alpine ${ALPINE}) ==="

DOCKER_BUILDKIT=1 docker build \
    $NO_CACHE \
    --secret id=signing_key,src=keys/packager.rsa \
    --build-arg ALPINE_VERSION="${ALPINE}" \
    --build-arg MODSEC_VER="${MODSEC_VER}" \
    --build-arg NGINX_VER="${NGINX_VER}" \
    --build-arg MODSEC_NGINX_VER="${MODSEC_NGINX_VER}" \
    --build-arg GEOIP2_VER="${GEOIP2_VER}" \
    --build-arg HEADERS_MORE_VER="${HEADERS_MORE_VER}" \
    --build-arg OWASP_CRS_VER="${OWASP_CRS_VER}" \
    --build-arg GEOIP_DB_VER="${GEOIP_DB_VER}" \
    --build-arg GEOIP_DB_MONTH="${GEOIP_DB_MONTH}" \
    --output type=local,dest=./public/ \
    --target output \
    --progress=plain \
    .

echo ""
echo "=== Done. Packages in public/v${ALPINE}/x86_64/ ==="
