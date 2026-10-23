#!/usr/bin/env bash
set -uo pipefail

PASS=0; FAIL=0

check() {  local desc="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo " [OK]  $desc"; ((PASS++))
  else
    echo " [FAIL] $desc (ожидалось: '$expected', получено: '$actual')"; ((FAIL++))
  fi  }

echo "Аудит конфигурации: $(hostname -f), $(date '+%Y-%m-%d %H:%M')"

echo "[1] Служба SSH"
check "Вход от имени root запрещён" "no" "$(sudo sshd -T | awk '/^permitrootlogin/{print $2}')"
check "Парольная аутентификация отключена" "no" "$(sudo sshd -T | awk '/^passwordauthentication/{print $2}')"

PORT=$(sudo sshd -T | awk '/^port /{print $2}')
if [[ "$PORT" != "22" ]]; then
  check "Порт SSH нестандартный (не 22)" "true" "true"
else
  check "Порт SSH нестандартный (не 22)" "true" "false"
fi

check "MaxAuthTries равен 3" "3" "$(sudo sshd -T | awk '/^maxauthtries/{print $2}')"
check "Межсетевой экран активен" "active" "$(sudo ufw status | awk '/^Status:/{print $2}')"
check "Политика входящего трафика deny" "deny" "$(sudo ufw status verbose | grep Default | grep -o 'deny' | head -n1)"

echo "[3] Учётные записи"
awk -F: ' $3>=1000 && $3<65534 {printf " %s (uid=%s)\n",$1,$3}' /etc/passwd

echo "[4] Веб-сервер"
# б) конфигурация nginx синтаксически корректна
if sudo nginx -t >/dev/null 2>&1; then
  check "Конфигурация Nginx корректна" "true" "true"
else
  check "Конфигурация Nginx корректна" "true" "false"
fi

# в) сертификат истекает не ранее чем через 30 дней
EXPIRY=$(sudo openssl x509 -checkend 2592000 -noout -in /etc/ssl/certs/devops.crt >/dev/null 2>&1 && echo "ok" || echo "expired")
check "Сертификат действителен (>30 дней)" "ok" "$EXPIRY"

# г) нет файлов с записью для всех и права ключа 600
WRITABLE=$(find /var/www/devops-site -perm -o+w | wc -l | tr -d ' ')
KEY_PERM=$(sudo stat -c '%a' /etc/ssl/private/devops.key)
if [[ "$WRITABLE" -eq 0 && "$KEY_PERM" == "600" ]]; then
  check "Права на файлы ресурса и ключ корректны" "true" "true"
else
  check "Права на файлы ресурса и ключ корректны" "true" "false"
fi

echo "Пройдено: $PASS, не пройдено: $FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1