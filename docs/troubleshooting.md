# Решение проблем

| Симптом | Вероятная причина | Что делать |
|---|---|---|
| `make master-install` падает: `Caddy is still bound to :443` | Ваш веб-сервер всё ещё слушает публичный :443 | Перенесите его на `127.0.0.1:8443`, публичным оставьте только :80. |
| `make master-install` бесконечно ждёт :8443 | Нет сайта на `127.0.0.1:8443` | Сначала запустите веб-сервер или используйте `MASTER_PRE_INSTALL`. |
| `MASTER_DOMAIN / SLAVE_DOMAIN missing` | Пустые значения в `master/.env` | Заполните оба (подойдёт и запланированный поддомен slave). |
| `skip inbound (no keys in .env): VLESS TCP REALITY NODE2` | `NODE2_REALITY_*` пусты | Нормально до добавления slave; иначе сгенерируйте ключи ([Добавление ноды](adding-a-node.md)). |
| `failed to obtain admin token` | Неверные `SUDO_*` или панель ещё не поднялась | Смотрите `make master-logs`; подождите и повторите `make master-hosts`. |
| Панель не открывается на `https://localhost:2053` | Туннель не открыт или не тот порт | `ssh -L 2053:127.0.0.1:2053 root@<ip_master>`; примите самоподписанный сертификат. |
| Не открывается `https://<master_domain>/` | DNS, ACME или нет сайта на :8443 | `dig +short`, `make master-status`, логи веб-сервера; порт 80 должен быть доступен. |
| URL подписки отдаёт 404/502 | `/sub/*` не проксируется на `127.0.0.1:2053` или неверный `XRAY_SUBSCRIPTION_URL_PREFIX` | Исправьте правило прокси; `{"detail":"Not Found"}` значит, что запрос доходит до Marzban (неверный токен). |
| Нода в статусе `error` / не подключена | Не тот сертификат, фаервол, неверный адрес | Повторите `make slave-cert` с сертификатом из панели, `make slave-up`; проверьте `nc -vz <ip_slave> 62050` с master и `PANEL_IP`. |
| Клиент подключается к master, но не к slave | Нет хоста NODE2, неверные SNI/IP, нет REDIRECT | Панель → Hosts → NODE2: `<ip_slave>`, 443, `<slave_domain>`; `make slave-firewall`; сравните `pbk`/`sid` с `NODE2_REALITY_*`. |
| У заглушки slave нет сертификата | ACME не прошёл | `docker logs node2-caddy`; порт 80 открыт; A-запись верна; без CDN-прокси. |
| После перезагрузки пропали правила (slave) | Сервис выключен | `systemctl enable --now node2-firewall.service`. |
| После перезагрузки на master открыт 8444 | Правило применяет только `master-start` | `make master-start` или сохраните правило. |
| Домен внутри контейнеров резолвится в старый IP | Устаревшая запись в `/etc/hosts` (контейнер копирует её при создании) | Удалите строку и пересоздайте контейнер (`make master-restart` на master; `docker compose -f slave/compose.yml --env-file slave/.env up -d --force-recreate` на slave). |
| IP сервера заблокирован | IP фильтруется цензором | Возьмите у хостера новый IP, обновите DNS, `PUBLIC_IP` и адрес хоста в панели. |

Не помогло? Пройдите [самопроверку](verification.md) по слоям и откройте issue с выводом команд (скройте IP, домены и ключи).
