# Эксплуатация

## Повседневные команды

| Команда | Сервер | Что делает |
|---|---|---|
| `make master-start` | master | Рендер конфига Xray, закрытие :8444, `compose up -d` |
| `make master-stop` | master | `compose down` |
| `make master-restart` | master | stop + start |
| `make master-status` / `master-logs` | master | Сводка состояния / логи |
| `make master-secrets` | master | Создаёт недостающие `.env`, сертификат панели, ключи REALITY (существующие не трогает) |
| `make master-hosts` | master | Выставляет SNI хоста master в `MASTER_DOMAIN` через API |
| `make slave-up` / `slave-down` | slave | Запуск / остановка контейнеров ноды |
| `make slave-firewall` | slave | Повторно применяет правила iptables (идемпотентно) |
| `make slave-status` / `slave-logs` | slave | Сводка состояния / логи |

Перезапуск master на несколько секунд обрывает активные соединения клиентов.

## Обновление

**Репозиторий**
```bash
git pull
make master-start     # master: перерендерит конфиг из шаблона
make slave-up         # slave: применит изменения compose
```
**Образы** закреплены по тегу *и* digest в `master/docker/compose.yml` и `slave/compose.yml`. Чтобы обновить, поменяйте оба, проверьте совместимость версий панели и ноды, затем `make master-restart` / `make slave-up`. Обновляйте ноды вместе с панелью.

## Бэкап

Всё состояние master — это `/var/lib/marzban` (база, отрендеренный конфиг, сертификаты панели) и `master/.env` (ключи, пароль админа):
```bash
tar czf marzban-backup-$(date +%F).tar.gz /var/lib/marzban master/.env
```
На slave: `slave/.env`, `/var/lib/marzban-node/ssl_client_cert.pem` и по желанию тома Caddy (сертификаты и так перевыпустятся). Храните бэкапы вне сервера — в них секреты.

## Восстановление / переезд master

1. Установите Docker, склонируйте репозиторий (см. [Быстрый старт](getting-started.md)).
2. Распакуйте: `tar xzf marzban-backup-<дата>.tar.gz -C /` восстановит `/var/lib/marzban`; верните `master/.env` в клон (поправьте `MASTER_IP`, если IP сменился).
3. Поднимите сайт на `127.0.0.1:8443`, затем `make master-start`.
4. Если IP сменился: обновите A-запись `<master_domain>`, `PANEL_IP` в каждом `slave/.env` + `make slave-firewall`, удалите устаревшие записи в `/etc/hosts`.

Пользователи и ключи сохраняются, существующие подписки продолжают работать.

## Фаервол

Скрипты только добавляют нужные им правила и никогда не сбрасывают чужие.

**master** — `master/scripts/block-node2-port.sh` (вызывается из `master-start`) вставляет `INPUT ! -i lo -p tcp --dport 8444 -j DROP` для iptables и ip6tables. Правило применяется при каждом старте, но не при загрузке системы само по себе; после перезагрузки выполните `make master-start` (или сохраните правило своими средствами).

**slave** — `slave/scripts/firewall.sh`, при загрузке через `node2-firewall.service`:
- 62050/62051: ACCEPT с `PANEL_IP` и loopback, остальное DROP (IPv6: только loopback);
- `nat PREROUTING -d PUBLIC_IP --dport 443 -j REDIRECT --to-ports INBOUND_PORT`;
- DROP :443 на остальных локальных адресах;
- DROP прямых подключений к :INBOUND_PORT, если пакет не был перенаправлен (`conntrack ! --ctstate DNAT`).

В своём фаерволе откройте 22, 80, 443/tcp на обоих серверах; 62050–62051/tcp на slave — только с master. Порт 2053 не открывайте никогда.
