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

# TODO 1: проверьте, что значение параметра port отлично от 22
PORT=$(sudo sshd -T | awk '/^port /{print $2}')
if [[ "$PORT" != "22" ]]; then
  check "Порт SSH нестандартный (не 22)" "true" "true"
else
  check "Порт SSH нестандартный (не 22)" "true" "false"
fi

# TODO 2: проверьте, что значение параметра maxauthtries равно 3
check "MaxAuthTries равен 3" "3" "$(sudo sshd -T | awk '/^maxauthtries/{print $2}')"

check "Межсетевой экран активен" "active" "$(sudo ufw status | awk '/^Status:/{print $2}')"

# TODO 3: проверьте, что политика по умолчанию для входящего трафика равна deny
# источник данных: sudo ufw status verbose | grep Default
check "Политика входящего трафика deny" "deny" "$(sudo ufw status verbose | grep Default | grep -o 'deny' | head -n1)"

echo "[3] Учётные записи"
awk -F: ' $3>=1000 && $3<65534 {printf " %s (uid=%s)\n",$1,$3}' /etc/passwd

echo "[5] Контейнеризация"
# a) служба docker активна
check "Служба Docker активна" "active" "$(systemctl is-active docker)"

# б) контейнер СУБД в состоянии healthy
check "СУБД в состоянии healthy" "healthy" "$(docker inspect -f '{{.State.Health.Status}}' app-db-1 2>/dev/null || echo 'not_found')"

# в) порты 5000 и 5432 не прослушиваются ни на одном адресе, кроме 127.0.0.1
# Проверяем, есть ли слушающие сокеты на этих портах, кроме локальных
BAD_PORTS=$(sudo ss -tln | grep -E ':(5000|5432)\s' | grep -v '127.0.0.1' | wc -l | tr -d ' ')
check "Порты 5000/5432 доступны только локально" "0" "$BAD_PORTS"

# г) права файла ~/app/.env равны 600
ENV_PERM=$(stat -c '%a' ~/app/.env)
check "Права .env равны 600" "600" "$ENV_PERM"

echo "Пройдено: $PASS, не пройдено: $FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
