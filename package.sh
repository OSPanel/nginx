#!/bin/bash
set -euo pipefail
shopt -s nullglob

log() {
  echo -e "\033[1;34m[PKG]\033[0m $*"
}
warn() {
  echo -e "\033[1;33m[WARN]\033[0m $*" 1>&2
}

TARGET_DIR="./Release"
SRC_BIN="/mingw64/bin"

mkdir -p "${TARGET_DIR}"
mkdir -p "${TARGET_DIR}/temp" "${TARGET_DIR}/logs"

cp_dll() {
  local pattern="$1"
  local found=0
  for f in ${SRC_BIN}/${pattern}; do
    if [[ -f "$f" ]]; then
      cp -f "$f" "${TARGET_DIR}/$(basename "$f")"
      found=1
    fi
  done
  if [[ $found -eq 0 ]]; then
    warn "Не найдено по маске: ${pattern}"
  else
    log "Скопировано: ${pattern}"
  fi
}

# Проверка зависимостей через ldd и докопирование недостающих
copy_missing_deps() {
  local exe
  for exe in "${TARGET_DIR}"/nginx-*.exe; do
    [[ -f "$exe" ]] || continue
    log "Проверка зависимостей: $(basename "$exe")"
    while read -r line; do
      # Примеры строк ldd: "libxyz-1.dll => /mingw64/bin/libxyz-1.dll (0x...)" или "libxyz-1.dll => not found"
      local lib path
      lib="$(echo "$line" | awk '{print $1}')"
      if echo "$line" | grep -q "=> /"; then
        path="$(echo "$line" | awk '{print $3}')"
        if [[ -f "$path" ]]; then
          cp -nf "$path" "${TARGET_DIR}/" || true
        fi
      elif echo "$line" | grep -q "not found"; then
        warn "Не найдена зависимость: $lib"
        # Пытаемся найти в /mingw64/bin
        if [[ -f "${SRC_BIN}/${lib}" ]]; then
          cp -f "${SRC_BIN}/${lib}" "${TARGET_DIR}/"
          log "Докопировано: ${lib}"
        fi
      fi
    done < <(ldd "$exe" || true)
  done
}
copy_missing_deps

# Конфиги и статика
if [[ -d nginx/conf ]]; then
  cp -rf nginx/conf "${TARGET_DIR}/"
fi
if [[ -d nginx/docs/html ]]; then
  mkdir -p "${TARGET_DIR}/docs"
  cp -rf nginx/docs/html "${TARGET_DIR}/"
fi
if [[ -d nginx/contrib ]]; then
  cp -rf nginx/contrib "${TARGET_DIR}/"
fi

PKG_NAME="${PKG_NAME:-nginx-bin.7z}"

log "Готово. Пакет: ${TARGET_DIR}/${PKG_NAME}"