#!/bin/bash
set -euo pipefail

# === Конфигурация ===
NGINX_TAG="${TAG:-}"
BUILD_USER_NAME="Build Bot"
BUILD_USER_EMAIL="nobody@example.com"
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
RELEASE_DIR="${REPO_ROOT}/Release"
DOCS_DIR="${RELEASE_DIR}/docs"

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

[[ -z "\(GIT_USER_NAME" ]] && git config --global user.name "\)BUILD_USER_NAME"
[[ -z "\(GIT_USER_EMAIL" ]] && git config --global user.email "\)BUILD_USER_EMAIL"

# === Каталоги ===
mkdir -p "${RELEASE_DIR}"
mkdir -p "${DOCS_DIR}"

# === Клонируем последние версии master + сабмодули ===
git clone --branch master --depth=1 --recursive https://github.com/google/ngx_brotli.git nginx_brotli_module
git clone --branch master --depth=1 --recursive https://github.com/aperezdc/ngx-fancyindex.git nginx_fancyindex
git clone --branch master --depth=1 --recursive https://github.com/leev/ngx_http_geoip2_module.git nginx_http_geoip2_module
git clone --branch main --depth=1 --recursive https://github.com/nginx/nginx-acme.git nginx_http_acme_module

# Патчим geoip2: заменяем во всех файлах нужную строку
find nginx_http_geoip2_module -type f -exec sed -i \
    's/ngx_file_info(database->mmdb.filename/ngx_file_info((u_char *) database->mmdb.filename/g' {} +

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

git am -3 ../*.patch || true

# === Загрузка зависимостей ===
download_and_extract "https://zlib.net/${ZLIB}.tar.xz" || \
download_and_extract "http://prdownloads.sourceforge.net/libpng/${ZLIB}.tar.xz"

WITH_PCRE="$PCRE"
if grep -q PCRE2_STATIC ./auto/lib/pcre/conf; then
  log "Используется PCRE2"
  WITH_PCRE="$PCRE2"
  download_and_extract "https://github.com/PhilipHazel/pcre2/releases/download/\({PCRE2}/\){PCRE2}.tar.bz2"
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
cp -pf "\({OPENSSL}/LICENSE.txt" "\){DOCS_DIR}/OpenSSL.LICENSE.txt" || true
cp -pf "\({WITH_PCRE}/LICENCE"* "\){DOCS_DIR}/PCRE.LICENCE" || true
if [[ -f "${ZLIB}/README" ]]; then
  sed -ne '/^ (C) 1995-20/,/^  jloup@gzip\.org/p' "\({ZLIB}/README" > "\){DOCS_DIR}/zlib.LICENSE" || true
  touch -r "\({ZLIB}/README" "\){DOCS_DIR}/zlib.LICENSE" || true
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
  --add-module=../nginx_http_acme_module
  --with-ld-opt="-Wl,--gc-sections,--build-id=none"
  --prefix=
  --with-http_v2_module
  "--with-openssl=${OPENSSL}"
  --with-http_ssl_module
  --with-mail_ssl_module
  --with-stream_ssl_module
  --with-stream_ssl_preread_module
)

# === Первая сборка (Release) ===
log "Конфигурация сборки (Release)"
auto/configure "${configure_args[@]}" \
  --with-cc-opt='-DFD_SETSIZE=32768 -s -O2 -fno-strict-aliasing -pipe' \
  --with-openssl-opt='-DFD_SETSIZE=32768 enable-ec_nistp_64_gcc_128 enable-camellia no-weak-ssl-ciphers no-ssl3 no-ssl3-method no-comp no-rc4 no-rc5 no-idea no-mdc2 no-seed no-shared no-tests -D_WIN32_WINNT=0x0601'

# === Pre-build всех C-зависимостей (fix race condition с Rust/bindgen) ===
# При make -j$(nproc) Rust-крейты nginx-sys и openssl-sys запускаются ПАРАЛЛЕЛЬНО
# с компиляцией OpenSSL/PCRE2/zlib и падают, не найдя заголовочных файлов:
#   - openssl/ssl.h (генерируется при install_sw OpenSSL)
#   - pcre2.h (генерируется из pcre2.h.in при configure PCRE2)
#   - zlib.h (есть в исходниках, но libz.a нужна для линковки)
# Решение: собрать все зависимости ПОСЛЕДОВАТЕЛЬНО через targets из nginx Makefile.

log "Pre-building zlib"
make -f objs/Makefile -j"$(nproc)" "${ZLIB}/libz.a"

log "Pre-building PCRE2 (needed by nginx-sys bindgen for pcre2.h)"
make -f objs/Makefile -j"$(nproc)" "${WITH_PCRE}/src/.libs/libpcre2-8.a"

log "Pre-building OpenSSL (needed by openssl-sys + nginx-sys bindgen)"
make -f objs/Makefile -j"$(nproc)" "${OPENSSL}/.openssl/include/openssl/ssl.h"

# === Установка путей OpenSSL для Rust openssl-sys ===
if [[ -d "${OPENSSL}/.openssl/lib64" ]]; then
  export OPENSSL_LIB_DIR="$(cygpath -m "$(pwd)/${OPENSSL}/.openssl/lib64")"
else
  export OPENSSL_LIB_DIR="$(cygpath -m "$(pwd)/${OPENSSL}/.openssl/lib")"
fi
export OPENSSL_INCLUDE_DIR="$(cygpath -m "$(pwd)/${OPENSSL}/.openssl/include")"
log "OPENSSL_LIB_DIR=${OPENSSL_LIB_DIR}"
log "OPENSSL_INCLUDE_DIR=${OPENSSL_INCLUDE_DIR}"

# === Полная параллельная сборка nginx (Release) ===
log "Сборка nginx (Release)"
make -j"$(nproc)"
strip -s objs/nginx.exe || true

version="$(grep NGINX_VERSION src/core/nginx.h | grep -oP '(\d+\.)+\d+')"
machine_str="$(gcc -dumpmachine | cut -d'-' -f1)"
mv -f /d/a/nginx/nginx/nginx/objs/nginx.exe "${RELEASE_DIR}/nginx.exe"

# Экспорт версии для последующих шагов (напр. упаковки)
echo "NGINX_VERSION=\({version}" > "\){RELEASE_DIR}/.env"

# === Сборка с отладкой (Debug) ===
log "Сборка с отладкой (Debug)"
configure_args+=(--with-debug)
auto/configure "${configure_args[@]}" \
  --with-cc-opt='-DFD_SETSIZE=32768 -O2 -fno-omit-frame-pointer -fno-strict-aliasing -pipe' \
  --with-openssl-opt='-DFD_SETSIZE=32768 no-shared no-tests -D_WIN32_WINNT=0x0601'

# Все C-зависимости уже собраны — touch чтобы make не пересобирал их заново
# (новый objs/Makefile от auto/configure новее чем эти файлы)
touch "${ZLIB}/libz.a"
touch "${WITH_PCRE}/src/.libs/libpcre2-8.a"
touch "${OPENSSL}/.openssl/include/openssl/ssl.h"

make -j"$(nproc)"
mv -f /d/a/nginx/nginx/nginx/objs/nginx.exe "${RELEASE_DIR}/nginx-debug.exe"

cd "${REPO_ROOT}"
