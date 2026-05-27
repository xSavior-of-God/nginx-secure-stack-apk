#!/bin/sh

# Updates versions.yml with latest upstream versions.
# Usage: ./update-versions.sh [--dry-run] [--pause]

DRY_RUN=false
PAUSE=false
for arg in "$@"; do
    [ "$arg" = "--dry-run" ] && DRY_RUN=true
    [ "$arg" = "--pause" ] && PAUSE=true
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

CONFIG="versions.yml"
ERRORS=0

yml_read() {
    sed -n "/^  $1:/,/^  [a-z]/{s/.*$2: \"\(.*\)\"/\1/p;}" "$CONFIG" | head -1
}

yml_write() {
    [ "$DRY_RUN" = true ] && return
    sed -i "/^  $1:/,/^  [a-z]/{s/$2: \"$3\"/$2: \"$4\"/;}" "$CONFIG"
}

github_latest() {
    ver=$(curl -s "https://api.github.com/repos/${1}/releases/latest" \
        | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' \
        | sed 's/^v//; s/^release-//')
    if [ -z "$ver" ]; then
        ver=$(curl -s "https://api.github.com/repos/${1}/tags" \
            | sed -n 's/.*"name": *"\([^"]*\)".*/\1/p' \
            | sed 's/^v//; s/^release-//' \
            | head -1)
    fi
    echo "$ver"
}

github_latest_stable() {
    curl -s "https://api.github.com/repos/${1}/tags" \
        | sed -n 's/.*"name": *"\([^"]*\)".*/\1/p' \
        | sed 's/^v//; s/^release-//' \
        | awk -F. '$2 % 2 == 0' \
        | head -1
}

check_update() {
    pkg="$1" cur="$2" new="$3" field="${4:-version}"
    if [ -z "$new" ]; then
        printf "  FAIL  %-22s %s (fetch failed)\n" "$pkg" "$cur"
        ERRORS=$((ERRORS + 1))
        return
    fi
    if [ "$cur" = "$new" ]; then
        printf "  OK    %-22s %s\n" "$pkg" "$cur"
    else
        printf "  NEW   %-22s %s -> %s\n" "$pkg" "$cur" "$new"
        yml_write "$pkg" "$field" "$cur" "$new"
    fi
}

echo "=== Checking latest versions ==="
echo ""

for pkg in libmodsecurity modsecurity-nginx geoip2 headers-more owasp-crs; do
    check_update "$pkg" \
        "$(yml_read "$pkg" version)" \
        "$(github_latest "$(yml_read "$pkg" github)")"
done

check_update nginx \
    "$(yml_read nginx version)" \
    "$(github_latest_stable "$(yml_read nginx github)")"

new_month=$(date -d "$(date +%Y-%m-01) -1 month" +%Y-%m 2>/dev/null \
    || date -v-1m +%Y-%m 2>/dev/null \
    || date +%Y-%m)
check_update geoip-db "$(yml_read geoip-db version)" "$(date +%Y.%m)"
check_update geoip-db "$(yml_read geoip-db month)" "$new_month" month

echo ""
if [ "$DRY_RUN" = true ]; then
    echo "=== Dry run. No files modified. ==="
elif [ "$ERRORS" -gt 0 ]; then
    echo "=== Done with $ERRORS error(s). Check failed packages above. ==="
    exit 1
else
    echo "=== versions.yml updated. Run ./build.sh to rebuild. ==="
fi
