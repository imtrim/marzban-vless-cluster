# Добавление slave-ноды

На slave работают `marzban-node` (REST, порты 62050/62051) и Caddy с сайтом-заглушкой для `<slave_domain>`. Панель сама передаёт ей конфиг Xray и пользователей. Нужен уже работающий master ([Быстрый старт](getting-started.md)).

## 1. Подготовка сервера

Повторите шаги 1–5 из [Быстрого старта](getting-started.md) для нового VPS: чистый IP, A-запись `<slave_domain>` → `<ip_slave>`, SSH-ключ, защита, Docker:
```bash
apt-get install -y git make && curl -fsSL https://get.docker.com | sh
```

## 2. Ключи NODE2 на master

Инбаунду slave `VLESS TCP REALITY NODE2` нужна своя пара ключей REALITY. На **master**:
```bash
docker exec marzban xray x25519      # Private key / Public key (или Password)
openssl rand -hex 8                  # short id
```
Впишите их в `master/.env`:
```
NODE2_REALITY_PRIVATE_KEY=...
NODE2_REALITY_PUBLIC_KEY=...
NODE2_REALITY_SHORT_ID=...
SLAVE_IP=<ip_slave>
SLAVE_DOMAIN=<slave_domain>
```
Затем перерендерите конфиг и перезапустите:
```bash
make master-start
```
Теперь `render-xray.sh` добавляет инбаунд NODE2 на :8444, а `block-node2-port.sh` закрывает внешний :8444 на master. Существующие пользователи сохраняются.

## 3. Нода в панели и её сертификат

Панель → **Nodes → Add node**:
- Address: адрес slave, доступный с master (`<ip_slave>`)
- Port `62050`, API port `62051`
- «Add this node as a new host for every inbound» **выключить**

Скопируйте сертификат из диалога (его же отдаёт API панели: `GET /api/node/settings`).

## 4. Установка slave

На **slave**:
```bash
git clone <url-репозитория> marzban-vless-cluster
cd marzban-vless-cluster
cp slave/.env.example slave/.env
nano slave/.env          # COVER_DOMAIN=<slave_domain>, PANEL_IP=<ip_master>, PUBLIC_IP=<ip_slave>
make slave-cert          # вставьте сертификат, затем Ctrl-D -> "saved"
make slave-install
```
`slave-install` применяет фаервол (62050/62051 только с `PANEL_IP`; `PUBLIC_IP:443` → `INBOUND_PORT`), ставит и включает `node2-firewall.service`, чтобы правила переживали перезагрузку, и запускает контейнеры `marzban-node` и `node2-caddy`. При желании замените страницы в `slave/site` на свой сайт-заглушку.

## 5. Хост для инбаунда NODE2

Панель → **Hosts → `VLESS TCP REALITY NODE2`**: адрес `<ip_slave>`, порт `443`, SNI `<slave_domain>`, fingerprint `chrome`. Удалите хост по умолчанию `{SERVER_IP}` у этого инбаунда (он указывал бы на master).

## 6. Пользователи

Ничего делать не нужно: Marzban хранит у пользователя только *исключённые* инбаунды, поэтому новый включён у всех, и в подписке теперь оба сервера. Обновите подписку в клиенте.

## 7. Проверка

Статус ноды в панели должен быть **connected**. Затем пройдите раздел про slave в [руководстве по самопроверке](verification.md).

## Третья нода и дальше

Каждая нода запускает все инбаунды, поэтому каждой нужен **свой порт**:
1. Поддомен `node3.<ваш-домен>` → чистый IP сервера N.
2. На master: сгенерируйте `NODE3_REALITY_*`, добавьте инбаунд `VLESS TCP REALITY NODE3` в `master/docker/xray_config.example.json` на новом порту (например 8445), пропишите его ключи и домен в `master/scripts/render-xray.sh` (словари `names` и `keys`) и закройте порт в `master/scripts/block-node2-port.sh`; `make master-start`.
3. На сервере N: `INBOUND_PORT=8445` в `slave/.env`, затем шаги 4–6 выше с хостом для инбаунда `NODE3`.
