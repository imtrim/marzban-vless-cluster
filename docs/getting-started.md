# Быстрый старт

Руководство начинается с «я только что купил VPS» и заканчивается рабочей подпиской пользователя на master. Второй сервер добавляется потом: [Добавление slave-ноды](adding-a-node.md).

## 1. Провайдер, локация и IP

- Подойдёт любой KVM VPS с **Ubuntu 22.04+** и публичным **IPv4**; для master хватит 1 vCPU / 1 ГБ RAM, ноде нужно ещё меньше.
- Локация ближе к пользователям, но вне цензурируемой сети (например, европейский ДЦ для пользователей из России). Разные провайдеры/локации для master и slave делают кластер устойчивее.
- IP должен быть **чистым**, то есть не заблокированным. Сразу после покупки проверьте из клиентской сети, что IP вообще отвечает (`ping <ip_master>`, `nc -vz <ip_master> 22`). Если он уже фильтруется, попросите у хостера другой IP. Если у сервера несколько IP, клиентам отдавайте чистый (`PUBLIC_IP` на slave).
- TCP 80 и 443 должны быть доступны из интернета (у некоторых хостеров есть ещё фаервол в панели).

## 2. DNS: один домен, по поддомену на сервер

Нужен один свой домен. Каждому серверу нужен только **поддомен**:

| Запись | Тип | Значение |
|---|---|---|
| `<master_domain>` (например `cdn.<ваш-домен>`) | A | `<ip_master>` |
| `<slave_domain>` (например `node2.<ваш-домен>`) | A | `<ip_slave>` |

Отключите CDN-проксирование («оранжевое облако»): REALITY и ACME нужны прямые соединения. Проверка: `dig +short <master_domain>` должен вывести `<ip_master>`.

## 3. SSH-ключи

На своём компьютере:
```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_master
ssh-copy-id -i ~/.ssh/id_ed25519_master.pub root@<ip_master>
ssh -i ~/.ssh/id_ed25519_master root@<ip_master>
```
По желанию добавьте алиас в `~/.ssh/config`:
```
Host master
  HostName <ip_master>
  User root
  IdentityFile ~/.ssh/id_ed25519_master
```

## 4. Базовая защита

На сервере, убедившись, что вход по ключу работает:
```bash
apt-get update && apt-get -y upgrade
apt-get install -y git make curl python3 openssl unattended-upgrades
# SSH только по ключу
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart ssh
```
Пока меняете настройки SSH, держите открытой вторую сессию. Скрипты репозитория добавляют только нужные им правила iptables (см. [Эксплуатация → Фаервол](operations.md#фаервол)); если используете ufw, разрешите 22, 80 и 443/tcp.

## 5. Установка Docker

```bash
curl -fsSL https://get.docker.com | sh
docker compose version
```

## 6. Клонирование репозитория

```bash
git clone <url-репозитория> marzban-vless-cluster
cd marzban-vless-cluster
```

## 7. Сайт на 127.0.0.1:8443

REALITY на master отправляет все не-VPN TLS-соединения на `127.0.0.1:8443` (сайт-заглушка). Этот веб-сервер в репозиторий **не входит**; подойдёт любой Caddy/nginx, который:

- отдаёт `master/site` по HTTPS для `<master_domain>` на `127.0.0.1:8443` (с настоящим сертификатом, например ACME HTTP-01 на порту 80);
- проксирует `/sub/*` на Marzban `https://127.0.0.1:2053` (сертификат панели самоподписанный, проверку апстрима отключите);
- **не** слушает публичный :443 (он нужен Xray).

`make master-install` ждёт :8443 и не продолжает, пока Caddy держит :443. Если перед установкой нужно запустить свой скрипт (например, поднять этот веб-сервер), задайте `MASTER_PRE_INSTALL=/путь/к/скрипту` или пропишите его в `local.mk` (он в `.gitignore`).

## 8. Настройка `master/.env`

```bash
cp master/.env.example master/.env
nano master/.env
```
Заполните как минимум `MASTER_IP`, `MASTER_DOMAIN`, `SLAVE_IP`, `SLAVE_DOMAIN`, `XRAY_SUBSCRIPTION_URL_PREFIX=https://<master_domain>` и надёжный `SUDO_PASSWORD`. Ключи `REALITY_*` оставьте пустыми, они сгенерируются. Если slave пока нет, всё равно впишите запланированный поддомен в `SLAVE_DOMAIN` (инбаунд NODE2 пропускается, пока `NODE2_REALITY_*` пусты). Полный список: [Конфигурация](configuration.md).

## 9. Установка master

```bash
make master-install
```
Запускается `master/scripts/install.sh`: создаёт самоподписанный сертификат панели в `/var/lib/marzban/certs`, генерирует ключи REALITY в `master/.env`, выполняет необязательный хук, ждёт сайт на :8443, рендерит `/var/lib/marzban/xray_config.json`, закрывает внешний :8444, запускает контейнер `marzban` и выставляет SNI хоста по умолчанию в `MASTER_DOMAIN`.

Проверка:
```bash
make master-status
```
Ожидается: контейнер `marzban` в состоянии `Up`, `panel 200`, `caddy-<master_domain> 200`, `public-<master_domain> 200`, а также публичный ключ REALITY, shortId, SNI и адрес.

## 10. Панель через SSH-туннель

Панель слушает только `127.0.0.1:2053`. С вашего компьютера:
```bash
ssh -L 2053:127.0.0.1:2053 root@<ip_master>
```
Откройте `https://localhost:2053/dashboard/` (примите самоподписанный сертификат). Логин и пароль: `SUDO_USERNAME` / `SUDO_PASSWORD` из `master/.env`.

## 11. Создание пользователя

В панели: **Users → Create user**, включите протокол **VLESS**, flow `xtls-rprx-vision`, оставьте отмеченным инбаунд `VLESS TCP REALITY`, задайте лимиты/срок и сохраните.

Проверить API прямо с сервера можно командой `make master-probe`: она создаёт (или берёт существующего) пользователя `probe`, отключает и снова включает его и печатает первую ссылку.

## 12. Получение подписки

Откройте пользователя в панели и скопируйте ссылку подписки вида `https://<master_domain>/sub/<token>`. Импортируйте её в клиент с поддержкой VLESS REALITY (v2rayN, v2rayNG, Hiddify, Streisand, NekoBox, sing-box…). Всё проверьте по [руководству по самопроверке](verification.md).

Дальше: [добавить slave-ноду](adding-a-node.md).
