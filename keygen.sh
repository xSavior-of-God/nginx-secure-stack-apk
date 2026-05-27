#!/bin/sh
set -e

ALPINE_VERSION=$(sed -n 's/^alpine: "\(.*\)"/\1/p' versions.yml)

echo "=== nginx-secure-stack-apk: APK Signing Key Generation ==="

if [ -f keys/packager.rsa ]; then
    echo ""
    echo "WARNING: keys/packager.rsa already exists."
    echo "Regenerating will invalidate all previously signed packages."
    echo ""
    printf "Continue? (y/N): "
    read -r CONFIRM
    [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ] || exit 0
fi

docker run --rm -v "$PWD:/work" -w /work "alpine:${ALPINE_VERSION}" sh -c "
    apk add --no-cache alpine-sdk
    mkdir -p keys
    PACKAGER='xSavior-of-God <https://github.com/xSavior-of-God>' abuild-keygen -an
    cp ~/.abuild/*.rsa keys/packager.rsa
    cp ~/.abuild/*.rsa.pub keys/packager.rsa.pub
"

echo ""
echo "=== Keys generated ==="
echo "  Private: keys/packager.rsa     (add to GitHub Secrets as APK_PRIVATE_KEY)"
echo "  Public:  keys/packager.rsa.pub (commit to repo)"
echo ""
echo "IMPORTANT: Do NOT commit keys/packager.rsa to git!"
