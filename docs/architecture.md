# Архитектура

## Компоненты

| Сервер | Компонент | Где |
|---|---|---|
| master | Панель Marzban v0.8.4 + ядро Xray (контейнер `marzban`, host network) | `master/docker/compose.yml` |
| master | Веб-сервер на `127.0.0.1:8443` (свой), отдаёт `master/site` и `/sub/*` | вне репозитория |
| slave | `marzban-node` v0.5.2, протокол REST (host network) | `slave/compose.yml` |
| slave | `node2-caddy` (Caddy 2.10), заглушка на `127.0.0.1:8443`, ACME на :80 | `slave/Caddyfile`, `slave/site` |
| slave | Правила iptables + `node2-firewall.service` | `slave/scripts/firewall.sh` |

## Поток трафика

### master
```
клиент ──TCP 443──▶ xray (инбаунд "VLESS TCP REALITY", SNI <master_domain>)
                      │ валидный клиент REALITY → freedom (интернет)
                      └ всё остальное (REALITY dest) ─▶ 127.0.0.1:8443
                                                          ├ <master_domain>        → master/site
                                                          └ <master_domain>/sub/*  → Marzban 127.0.0.1:2053
127.0.0.1:2053  панель + API (только SSH-туннель)
:8444           инбаунд NODE2 тоже запущен здесь; снаружи закрыт block-node2-port.sh
```

### slave
```
клиент ──TCP <ip_slave>:443──▶ iptables REDIRECT ──▶ xray :8444 (инбаунд "VLESS TCP REALITY NODE2", SNI <slave_domain>)
                                                       └ fallback ─▶ Caddy 127.0.0.1:8443 → slave/site
:62050 REST API ноды, :62051 API Xray — только с <ip_master>
```

## Почему инбаунд slave на 8444

Marzban 0.8.4 запускает **все** инбаунды из `xray_config.json` и на ядре панели, **и** на каждой ноде. Два инбаунда не могут делить :443 на одном хосте, поэтому инбаунд NODE2 везде слушает :8444:
- на slave `PUBLIC_IP:443` перенаправляется на :8444, а сам :8444 принимает только перенаправленные (DNAT) пакеты;
- на master внешний :8444 закрыт;
- инбаунд master тоже стартует на slave на :443, но трафика не получает: :443 на других адресах закрыт.

## Рендер конфига

`master/scripts/render-xray.sh` собирает `/var/lib/marzban/xray_config.json` из `master/docker/xray_config.example.json` и `master/.env`: подставляет приватные ключи, short id и server names по тегу инбаунда, сохраняет текущих `clients` каждого тега (пользователи не теряются) и пропускает инбаунд с пустыми ключами. Запускается при каждом `make master-start`.

## Пользователи и подписки

Marzban хранит у пользователя инбаунды, из которых он *исключён*, поэтому новый инбаунд включён у всех. У каждого инбаунда есть хосты (Панель → Hosts) — они задают адрес и SNI в ссылках подписки. `configure-hosts.sh` выставляет SNI хоста инбаунда master в `MASTER_DOMAIN`; хост NODE2 настраивается вручную.

## Доверие между master и нодой

Нода принимает только клиентов с сертификатом панели из `/var/lib/marzban-node/ssl_client_cert.pem` (`make slave-cert`), а её порты закрыты фаерволом для всех, кроме `PANEL_IP`.
