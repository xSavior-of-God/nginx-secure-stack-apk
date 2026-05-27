# nginx-secure-stack-apk

###### Developed by [xSavior_of_God](https://github.com/xSavior-of-God)

![Nginx](https://img.shields.io/badge/nginx-%23009639.svg?style=for-the-badge&logo=nginx&logoColor=white)
![Alpine Linux](https://img.shields.io/badge/Alpine_Linux-%230D597F.svg?style=for-the-badge&logo=alpine-linux&logoColor=white)
![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)
![OWASP_ModSecurity](https://img.shields.io/badge/🔰_OWASP_ModSecurity-A19F9F.svg?style=for-the-badge)
![Brotli](https://img.shields.io/badge/brotli-%23009688.svg?style=for-the-badge&logo=data:image/svg%2Bxml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA1MTIgNTEyIj48ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSgyNTYsMjU2KXNjYWxlKDI0KXJvdGF0ZSgxNSkiIHN0eWxlPSJmaWxsOiNmZmY7Ij48Y2lyY2xlIHN0eWxlPSJmaWxsOiNlYTMiIHI9IjEwIi8+PGVsbGlwc2Ugcng9IjIiIHJ5PSI4Ii8+PGVsbGlwc2UgY3g9IjUiIHJ4PSIxIiByeT0iNCIvPjxlbGxpcHNlIGN4PSItNSIgcng9IjEiIHJ5PSI0Ii8+PC9nPjwvc3ZnPg==)

<br/>

Pre-built Alpine APK packages for a **hardened NGINX stack**: ModSecurity WAF + GeoIP2 + Brotli + headers-more.
Replaces ~100 lines of Dockerfile build logic with a single `apk add`.

---

## 📦 Packages

| Package          | Description                                                       |
| ---------------- | ----------------------------------------------------------------- |
| `libmodsecurity` | ModSecurity v3 WAF engine                                         |
| `nginx-modsec`   | NGINX with dynamic modules (modsec, geoip2, headers-more, brotli) |
| `owasp-crs`      | OWASP ModSecurity Core Rule Set                                   |
| `nginx-geoip-db` | DB-IP Country & City Lite databases                               |

<br/>

## ⁉ How does it work?

This repository builds signed Alpine APK packages using a multi-stage Dockerfile, then publishes them to **GitHub Pages** as a standard APK repository. Your downstream Dockerfiles just add the repo URL and install packages - no compilation needed.

```
Build (CI)                                  Install (your Dockerfile)
──────────                                  ─────────────────────────
1. Docker builds all packages               1. COPY public key into image
   from source with abuild                     /etc/apk/keys/packager.rsa.pub
        │                                            │
2. Each .apk + APKINDEX.tar.gz              2. Add repo URL to /etc/apk/repositories
   signed with RSA private key                       │
        │                                            │
3. Signed packages deployed                 3. apk add --no-cache nginx-modsec ...
   to GitHub Pages                             apk verifies RSA signature → install
```

<br/>

## 💻 Usage

Add the APK repository and install packages in your Dockerfile:

```dockerfile
FROM php:8.5.5-alpine

# ---- PHP extensions (your existing setup) ----
RUN apk add --no-cache \
        curl bash redis supervisor \
        openldap-dev libldap libmagic

RUN apk add --no-cache --virtual .build-deps $PHPIZE_DEPS autoconf build-base \
  && pecl install redis \
  && docker-php-ext-enable redis \
  && docker-php-ext-configure ldap \
  && docker-php-ext-install pcntl pdo pdo_mysql ldap fileinfo \
  && apk del .build-deps \
  && rm -rf /tmp/* /var/cache/apk/*

# ---- NGINX + ModSecurity + GeoIP (from pre-built APKs) ----
COPY keys/packager.rsa.pub /etc/apk/keys/packager.rsa.pub
RUN echo "https://xSavior-of-God.github.io/nginx-secure-stack-apk/v3.23.4/x86_64" >> /etc/apk/repositories \
  && apk add --no-cache \
       nginx-modsec \
       libmodsecurity \
       owasp-crs \
       nginx-geoip-db

# ---- Everything below stays the same ----
# ... rest of your Dockerfile
```

<br/>

## 🔒 Package Integrity & Signing

All packages are signed with **RSA (4096-bit)** - the same mechanism Alpine Linux uses for its official repositories.

No additional checksums (MD5, SHA256) are published because the RSA signature already provides both:

- **Integrity** - any modification to a package after signing breaks the signature, so `apk` refuses to install it
- **Authenticity** - only the holder of the private key can produce valid signatures, proving packages came from this repository

The private key (`keys/packager.rsa`) is **never committed** to the repository - it is stored in GitHub Secrets (`APK_PRIVATE_KEY`) and injected at build time via Docker BuildKit's `--secret` mount, which ensures it never appears in any image layer.

<br/>

## 📌 Setup

### 1. Generate signing keys (one-time)

```sh
./keygen.sh
```

### 2. Build packages

```sh
./build.sh
```

Requires Docker with BuildKit support. Outputs to `public/v<alpine_version>/x86_64/`.

<details>
<summary>Build options</summary>

```sh
./build.sh --no-cache   # Force full rebuild
./build.sh --pause      # Wait for keypress before exiting
```

</details>

### 3. GitHub Actions (CI/CD)

1. Add `keys/packager.rsa` content to GitHub Secrets as `APK_PRIVATE_KEY`
2. Commit and push `keys/packager.rsa.pub`
3. Enable GitHub Pages (deploy from `gh-pages` branch)
4. Push a tag to trigger build + deploy:
   ```sh
   git tag v1.0.0 && git push --tags
   ```

<br/>

## 🔄 Version Management

All package versions are tracked in `versions.yml` and checked against the GitHub API.

```sh
# Check for new upstream versions
./update-versions.sh --dry-run

# Apply updates to versions.yml
./update-versions.sh
```

<details>
<summary>Output example</summary>

```
=== Checking latest versions ===

  OK    libmodsecurity         3.0.15
  OK    modsecurity-nginx      1.0.4
  OK    geoip2                 3.4
  NEW   headers-more           0.38 -> 0.39
  OK    owasp-crs              4.26.0
  OK    nginx                  1.30.2
  OK    geoip-db               2026.05

=== versions.yml updated. Run ./build.sh to rebuild. ===
```

</details>
