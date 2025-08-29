#!/bin/bash
set -euo pipefail

# === Конфигурация ===
NGINX_TAG="${TAG:-}"
BUILD_USER_NAME="Build Bot"
BUILD_USER_EMAIL="nobody@example.com"
RELEASE_DIR="../Release"
DOCS_DIR="${RELEASE_DIR}/docs"
mkdir -p ${DOCS_DIR}

# === Утилиты ===
log() {
  echo -e "\033[1;32m[INFO]\033[0m $*"
}

fetch_latest_version() {
  local url="$1"
  local pattern="$2"
  local fallback="$3"
  curl -s "$url" | grep -ioP "$pattern" | sort -ruV | head -1 || echo "$fallback"
}

download_and_extract() {
  local url="$1"
  local archive="${url##*/}"

  wget -c -nv "$url"
  case "$archive" in
    *.tar.gz) tar -xf "$archive" ;;
    *.tar.bz2) tar -xf "$archive" ;;
    *.tar.xz) tar -xf "$archive" ;;
    *) log "Неизвестный формат: $archive"; exit 1 ;;
  esac
}

# === Настройка Git ===
GIT_USER_NAME="$(git config --global user.name || echo "")"
GIT_USER_EMAIL="$(git config --global user.email || echo "")"

[[ -z "$GIT_USER_NAME" ]] && git config --global user.name "$BUILD_USER_NAME"
[[ -z "$GIT_USER_EMAIL" ]] && git config --global user.email "$BUILD_USER_EMAIL"

# === Каталоги ===
mkdir -p "${RELEASE_DIR}"
mkdir -p "${DOCS_DIR}"

# === Получение версий зависимостей ===
ZLIB="$(fetch_latest_version 'https://zlib.net/' 'zlib-(\d+\.)+\d+' 'zlib-1.3.1')"
PCRE="$(fetch_latest_version 'https://sourceforge.net/projects/pcre/rss?path=/pcre/' 'pcre-(\d+\.)+\d+' 'pcre-8.45')"
PCRE2="$(fetch_latest_version 'https://api.github.com/repos/PhilipHazel/pcre2/releases/latest' 'pcre2-(\d+\.)+\d+' 'pcre2-10.45')"
OPENSSL="$(fetch_latest_version 'https://openssl-library.org/source/' 'openssl-3\.5\.\d+' 'openssl-3.5.2')"

log "Zlib: $ZLIB"
log "PCRE: $PCRE"
log "PCRE2: $PCRE2"
log "OpenSSL: $OPENSSL"

# === Клонирование и патчи nginx ===
log "Клонирование nginx"
if [[ -d nginx ]]; then
  rm -rf nginx
fi

if [[ -z "$NGINX_TAG" ]]; then
  git clone --depth=1 https://github.com/nginx/nginx.git
else
  git clone --depth=1 --branch "$NGINX_TAG" https://github.com/nginx/nginx.git
fi
cd nginx || exit 1

git checkout -b patch || git checkout patch
mkdir -p docs

# Отключение патчей, если utf16 поддерживается
if grep -q 'ngx_utf16_to_utf8' src/os/win32/ngx_files.c; then
  log "UTF-16 уже поддерживается, удаление старых патчей"
  rm -f ../nginx-000{2..6}-*.patch || true
fi

git am -3 ../nginx-*.patch || true

# === Загрузка зависимостей ===
download_and_extract "https://zlib.net/${ZLIB}.tar.xz" || \
download_and_extract "http://prdownloads.sourceforge.net/libpng/${ZLIB}.tar.xz"

WITH_PCRE="$PCRE"
if grep -q PCRE2_STATIC ./auto/lib/pcre/conf; then
  log "Используется PCRE2"
  WITH_PCRE="$PCRE2"
  download_and_extract "https://github.com/PhilipHazel/pcre2/releases/download/${PCRE2}/${PCRE2}.tar.bz2"
else
  download_and_extract "https://download.sourceforge.net/project/pcre/pcre/$(echo $PCRE | sed 's/pcre-//')/${PCRE}.tar.bz2"
fi

download_and_extract "https://www.openssl.org/source/${OPENSSL}.tar.gz"

# Исправление openssl-1.1.1d (на всякий)
if [[ "$OPENSSL" == "openssl-1.1.1d" ]]; then
  sed -i 's/return return 0;/return 0;/' openssl-1.1.1d/crypto/threads_none.c
fi

# === Документация и лицензии ===
make -f docs/GNUmakefile changes || true
mv -f tmp/*/CHANGES* "${DOCS_DIR}/" || true

cp -f LICENSE README.md "${DOCS_DIR}/" || true
cp -pf "${OPENSSL}/LICENSE.txt" "${DOCS_DIR}/OpenSSL.LICENSE.txt" || true
cp -pf "${WITH_PCRE}/LICENCE"* "${DOCS_DIR}/PCRE.LICENCE" || true
if [[ -f "${ZLIB}/README" ]]; then
  sed -ne '/^ (C) 1995-20/,/^  jloup@gzip\.org/p' "${ZLIB}/README" > "${DOCS_DIR}/zlib.LICENSE" || true
  touch -r "${ZLIB}/README" "${DOCS_DIR}/zlib.LICENSE" || true
fi

# === Конфигурация сборки ===
configure_args=(
  --sbin-path=nginx.exe
  --conf-path=conf/nginx.conf
  --pid-path=nginx.pid
  --http-log-path=access.log
  --error-log-path=error.log
  --http-client-body-temp-path=temp/client_body
  --http-proxy-temp-path=temp/proxy
  --http-fastcgi-temp-path=temp/fastcgi
  --http-scgi-temp-path=temp/scgi
  --http-uwsgi-temp-path=temp/uwsgi
  --with-http_realip_module
  --with-http_addition_module
  --with-http_sub_module
  --with-http_dav_module
  --with-http_stub_status_module
  --with-http_flv_module
  --with-http_mp4_module
  --with-http_gunzip_module
  --with-http_gzip_static_module
  --with-http_auth_request_module
  --with-http_image_filter_module
  --with-http_random_index_module
  --with-http_secure_link_module
  --with-http_slice_module
  --with-stream_realip_module
  --with-mail
  --with-stream
  --with-poll_module
  "--with-pcre=${WITH_PCRE}"
  --with-pcre-jit
  "--with-zlib=${ZLIB}"
  --with-http_geoip_module
  --with-stream_geoip_module
  --add-module=../nginx_brotli_module
  --add-module=../nginx_http_geoip2_module
  --add-module=../nginx_fancyindex
  --with-ld-opt="-Wl,--gc-sections,--build-id=none"
  --prefix=
  --with-http_v2_module
)

# === Первая сборка (Release) ===
log "Конфигурация сборки (Release)"
auto/configure "${configure_args[@]}" \
  --with-cc-opt='-DFD_SETSIZE=32768 -s -O2 -fno-strict-aliasing -pipe'

log "Сборка nginx (Release)"
make -j"$(nproc)"
strip -s objs/nginx.exe || true

version="$(grep NGINX_VERSION src/core/nginx.h | grep -oP '(\d+\.)+\d+')"
machine_str="$(gcc -dumpmachine | cut -d'-' -f1)"
mv -f objs/nginx.exe "${RELEASE_DIR}/nginx-${version}-${machine_str}.exe"

# Экспорт версии для последующих шагов (напр. упаковки)
echo "NGINX_VERSION=${version}" > ../Release/.env


cd ..