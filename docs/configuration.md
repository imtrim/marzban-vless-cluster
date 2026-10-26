# Конфигурация

Оба файла `.env` в `.gitignore`. Начинайте с `.env.example` рядом с ними.

## `master/.env`

Загружается контейнером `marzban` (`env_file`) и читается скриптами `master/scripts/*`.

| Переменная | По умолчанию (пример) | Назначение |
|---|---|---|
| `UVICORN_HOST` | `127.0.0.1` | Адрес панели. Оставьте localhost. |
| `UVICORN_PORT` | `2053` | Порт панели/API; его же используют скрипты и SSH-туннель. |
| `UVICORN_SSL_CERTFILE` / `UVICORN_SSL_KEYFILE` | `/var/lib/marzban/certs/panel.crt` / `.key` | Самоподписанный сертификат панели от `setup-secrets.sh`. |
| `UVICORN_SSL_CA_TYPE` | `private` | Сообщает Marzban, что сертификат частный/самоподписанный. |
| `SUDO_USERNAME` / `SUDO_PASSWORD` | `admin` / `change-me` | Логин админа панели; при создании `.env` `setup-secrets.sh` генерирует случайный пароль. |
| `SQLALCHEMY_DATABASE_URL` | `sqlite:////var/lib/marzban/db.sqlite3` | База Marzban. |
| `XRAY_JSON` | `/var/lib/marzban/xray_config.json` | Отрендеренный конфиг Xray. |
| `XRAY_SUBSCRIPTION_URL_PREFIX` | `https://<master_domain>` | Основа ссылок подписки (`…/sub/<token>`). |
| `MASTER_IP` | `<ip_master>` | Публичный IP master (вывод статуса, подсказка туннеля). |
| `MASTER_DOMAIN` | `<master_domain>` | SNI REALITY и заглушка инбаунда master. |
| `MASTER_EXTRA_DOMAINS` | пусто | Доп. SNI (через пробел), которые отдаёт тот же сайт на master. |
| `SLAVE_IP` | `<ip_slave>` | Публичный IP slave (для справки). |
| `SLAVE_DOMAIN` | `<slave_domain>` | SNI REALITY инбаунда NODE2. Обязателен для `render-xray.sh`. |
| `MARZBAN_DATA` | `/var/lib/marzban` | Каталог данных, монтируется в контейнер. |
| `REALITY_PRIVATE_KEY` / `REALITY_PUBLIC_KEY` / `REALITY_SHORT_ID` | генерируются | Ключи инбаунда master (`setup-secrets.sh`). |
| `NODE2_REALITY_PRIVATE_KEY` / `NODE2_REALITY_PUBLIC_KEY` / `NODE2_REALITY_SHORT_ID` | пусто | Ключи инбаунда slave; генерируются вручную (см. [Добавление ноды](adding-a-node.md)). Пусто → инбаунд пропускается. |

Переменные только для скриптов (окружение, не `.env`): `NODE2_INBOUND_PORT` (по умолчанию `8444`) для `block-node2-port.sh`; `MASTER_PRE_INSTALL` — путь к скрипту, который `make master-install` запускает перед стартом Marzban (в командной строке или в `local.mk`).

## `slave/.env`

Читается скриптами `slave/scripts/*` и передаётся в `slave/compose.yml`.

| Переменная | По умолчанию | Назначение |
|---|---|---|
| `COVER_DOMAIN` | `<slave_domain>` | Домен сайта-заглушки Caddy (сертификат через ACME). |
| `PANEL_IP` | `<ip_master>` | Единственный источник, которому открыты 62050/62051. |
| `PUBLIC_IP` | `<ip_slave>` | Чистый IP для клиентов; перенаправляется только его :443. Пусто = все локальные адреса. |
| `SERVICE_PORT` | `62050` | REST-порт marzban-node. |
| `XRAY_API_PORT` | `62051` | Порт API Xray. |
| `PUBLIC_PORT` | `443` | Публичный порт для клиентов. |
| `INBOUND_PORT` | `8444` | Порт инбаунда *этой* ноды (8444 для NODE2, 8445 для NODE3, …). |

## Локальные переопределения

`local.mk` (подключается в Makefile через `-include`) и `local/` в `.gitignore`: туда кладите переменные и скрипты конкретного сервера, например
```make
MASTER_PRE_INSTALL := $(ROOT)/local/my-pre-install.sh
```
