#!/usr/bin/env bash
# Доставка статического ресурса на devops-vm
set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"
LOCAL_DIR="$(git rev-parse --show-toplevel)/site"

# 1. Разбор аргумента --dry-run
DRY_RUN=""
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN="--dry-run"
fi

# 2. Проверки по требованиям 4 и 5
if [[ ! -f "${LOCAL_DIR}/index.html" ]]; then
    echo "Ошибка: файл site/index.html отсутствует. Доставка отменена." >&2
    exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
    echo "Ошибка: в репозитории есть незафиксированные изменения. Доставка отменена." >&2
    exit 1
fi

# 3. Синхронизация каталога
echo "Синхронизация ${LOCAL_DIR}/ на ${REMOTE}:${REMOTE_DIR}/"
rsync -avz --delete --chmod=D755,F644 ${DRY_RUN} "${LOCAL_DIR}/" "${REMOTE}:${REMOTE_DIR}/"

# 4. При --dry-run — завершение с кодом 0
if [[ -n "${DRY_RUN}" ]]; then
    echo "Пробный запуск завершен."
    exit 0
fi

# 5. Проверка доступности
echo "Проверка доступности ${SITE_URL}..."
if ! curl -f --cacert "${CA_CERT}" -s -o /dev/null "${SITE_URL}"; then
    echo "Ошибка: ресурс ${SITE_URL} недоступен после деплоя." >&2
    exit 1
fi

echo "Деплой успешно завершен. Коммит: $(git rev-parse --short HEAD)"
exit 0
