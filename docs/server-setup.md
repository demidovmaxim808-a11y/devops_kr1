# Конфигурация виртуальной машины devops-vm

## 1. Параметры машины
- Объем памяти: 2048 МБ
- Количество ядер процессора: 2
- Объем диска: 25 ГБ (динамический)

## 2. Сетевые интерфейсы
- **Адаптер 1 (NAT):** IP 10.0.2.15, используется для доступа в интернет и проброса портов.
- **Адаптер 2 (Host-only):** IP 192.168.56.101, используется для связи с хостом (назначен вручную из-за отсутствия DHCP на Mac M5).

## 3. Правило проброса портов
- Порт хостовой системы: 2222
- Порт гостевой системы: 2222

## 4. Учётные записи
- `student`: входит в группу `sudo`, аутентификация по паролю.
- `devops`: входит в группу `sudo`, аутентификация по ключу (ed25519).

## 5. Служба SSH
- Порт: 2222
- Изменённые директивы (в `/etc/ssh/sshd_config.d/10-hardening.conf`):
  - Port 2222
  - PermitRootLogin no
  - PasswordAuthentication no
  - PubkeyAuthentication yes
  - MaxAuthTries 3
  - AllowUsers devops
  - X11Forwarding no

## 6. Правила межсетевого экрана (UFW)
- Политика по умолчанию: deny incoming, allow outgoing.
- Разрешенные правила:
  - 2222/tcp (LIMIT, комментарий 'SSH rate-limited')
  - 80/tcp (HTTP)
  - 443/tcp (HTTPS)

## 7. Снимки состояния
1. `01-clean-install` — чистая установка Ubuntu Server.
2. `02-keys-configured` — настроены SSH-ключи для devops.
3. `03-ssh-hardened` — изменен порт на 2222, отключена парольная аутентификация, включен UFW.
4. `04-dns-configured` — настроено локальное доменное имя devops.local и FQDN.

## 8. Веб-сервер
- Устанавливаемый пакет: `nginx`
- Путь к конфигурации ресурса: `/etc/nginx/sites-available/devops-site`
- Каталог ресурса: `/var/www/devops-site`, владелец `devops:devops`, права `755` для каталогов и `644` для файлов
- Путь к сертификату: `/etc/ssl/certs/devops.crt` (права `644`, владелец `root`)
- Путь к ключу: `/etc/ssl/private/devops.key` (права `600`, владелец `root`)
- Команда формирования сертификата: `sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/devops.key -out /etc/ssl/certs/devops.crt -subj "/CN=devops.local" -addext "subjectAltName=DNS:devops.local"`
- Срок действия сертификата: 365 дней
