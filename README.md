# marzban-vless-cluster — кластер Marzban + VLESS REALITY на нескольких серверах

[![License](https://img.shields.io/github/license/imtrim/marzban-vless-cluster)](LICENSE)
[![Marzban](https://img.shields.io/badge/Marzban-v0.8.4-blue)](https://github.com/Gozargah/Marzban)
[![Marzban Node](https://img.shields.io/badge/Marzban%20Node-v0.5.2-blue)](https://github.com/Gozargah/Marzban-node)
[![Xray](https://img.shields.io/badge/Xray-VLESS%20REALITY-purple)](https://github.com/XTLS/Xray-core)
[![Docker Compose](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)](https://docs.docker.com/compose/)
[![Docs](https://img.shields.io/badge/docs-RU-red)](docs/README.md)
[![Last commit](https://img.shields.io/github/last-commit/imtrim/marzban-vless-cluster)](https://github.com/imtrim/marzban-vless-cluster/commits/main)

Готовая конфигурация для обхода блокировок на своих VPS: панель [Marzban](https://github.com/Gozargah/Marzban) на одном сервере и [Marzban Node](https://github.com/Gozargah/Marzban-node) на остальных, VLESS TCP REALITY с XTLS Vision на ядре [Xray](https://github.com/XTLS/Xray-core), всё в Docker. Несколько серверов в одной подписке: пользователь импортирует одну ссылку и получает все серверы кластера. Сервер `master` держит панель и свой Xray, каждый `slave` получает от панели конфиг и пользователей; у каждого сервера свой инбаунд REALITY со своим сайтом-заглушкой (self-steal). Отдельный домен на каждый сервер не нужен: хватит одного домена и поддомена на каждый сервер, например `<master_domain>` = `cdn.<ваш-домен>`, `<slave_domain>` = `node2.<ваш-домен>`.

```
master/   сервер с панелью: стек Marzban, шаблон конфига Xray, сайт-заглушка <master_domain>
slave/    нода: marzban-node, Caddy с заглушкой <slave_domain>, фаервол, установка
Makefile  цели master-* и slave-*
```

Все реальные адреса живут только в `master/.env` и `slave/.env` (в git не попадают). В репозитории вместо них плейсхолдеры: `<ip_master>`, `<ip_slave>`, `<master_domain>`, `<slave_domain>`.

> [!WARNING]
> - IP и подсети популярных хостеров могут быть заблокированы ТСПУ; проверяйте IP до покупки и развёртывания. Чистый IP может «сгореть» в любой момент.
> - VLESS/REALITY может перестать работать из-за РКН когда угодно: гарантий и SLA нет, держите запасной вариант.
> - Скрипты и Docker работают с правами root: используйте отдельного sudo-пользователя, вход только по ключу, фаервол и обновления, не открывайте панель наружу.
> - Проект предоставляется «как есть», для обучения и защиты своего трафика. За соблюдение законов и правил хостера отвечаете вы.
>
> Подробнее: [docs/warnings.md](docs/warnings.md).

## Документация

- [Быстрый старт](docs/getting-started.md): от только что купленного VPS до рабочей подписки
- [Добавление slave-ноды](docs/adding-a-node.md)
- [Самопроверка](docs/verification.md): проверка каждого слоя своими руками
- [Архитектура](docs/architecture.md)
- [Конфигурация](docs/configuration.md): справочник по `.env`
- [Эксплуатация](docs/operations.md): обновление, бэкап и восстановление, фаервол
- [Решение проблем](docs/troubleshooting.md)
- [FAQ](docs/faq.md)
- [Предупреждения](docs/warnings.md): ТСПУ, блокировки, безопасность, ответственность

Полный список: [docs/README.md](docs/README.md). Для ИИ-ассистентов: [AGENTS.md](AGENTS.md), [llms.txt](llms.txt).

## Начало работы

Нужны: VPS на Ubuntu 22.04+ с чистым IPv4 на каждый сервер, Docker с compose, `git`, `make`, `curl`, `python3`, `openssl`; один домен с поддоменом-A-записью на каждый сервер (без CDN-прокси); на master — свой веб-сервер на `127.0.0.1:8443`, который отдаёт `master/site` и проксирует `/sub/*` на панель.

Быстрый старт на master:
```bash
git clone <url-репозитория> marzban-vless-cluster && cd marzban-vless-cluster
cp master/.env.example master/.env     # MASTER_IP, MASTER_DOMAIN, SLAVE_IP, SLAVE_DOMAIN
make master-install
make master-status
ssh -L 2053:127.0.0.1:2053 root@<ip_master>   # с вашего компьютера → https://localhost:2053/dashboard/
```

Подробно:
- [Быстрый старт](docs/getting-started.md): от покупки VPS до подписки, пошагово
- [Добавление slave-ноды](docs/adding-a-node.md): ключи NODE2, `make slave-cert`, `make slave-install`, настройка в панели, третья нода и дальше
- [Архитектура](docs/architecture.md): как идёт трафик и почему инбаунд slave на 8444
- [Конфигурация](docs/configuration.md): все переменные `.env`

## Запуск тестов

Автотестов нет: `make master-status` и `make slave-status` плюс пошаговая [самопроверка](docs/verification.md) (порты, контейнеры, REALITY, заглушка, подписка, нода, клиент, логи).

## Развёртывание

Обновление, бэкап и восстановление, фаервол: [Эксплуатация](docs/operations.md). Если что-то не работает: [Решение проблем](docs/troubleshooting.md). Панель (2053) наружу не открывайте.

## Используемые технологии

- [Marzban](https://github.com/Gozargah/Marzban) v0.8.4: панель и подписки
- [Marzban Node](https://github.com/Gozargah/Marzban-node) v0.5.2
- [Xray-core](https://github.com/XTLS/Xray-core): VLESS + REALITY + XTLS Vision
- [Caddy](https://caddyserver.com/) 2.10: сайты-заглушки и ACME
- Docker Compose, iptables, POSIX sh

## Участие в разработке

Подробности в [CONTRIBUTING.md](CONTRIBUTING.md), правила общения — в [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md). Об уязвимостях сообщайте приватно, см. [SECURITY.md](SECURITY.md). Не коммитьте `.env`, ключи, сертификаты и реальные IP или домены: используйте плейсхолдеры.

## Версионирование

Версии проекта — по [SemVer](https://semver.org/lang/ru/), изменения в [CHANGELOG.md](CHANGELOG.md). Образы закреплены по тегу и digest (`master/docker/compose.yml`, `slave/compose.yml`). Обновляйте их осознанно и проверяйте совместимость панели и ноды.

## Авторы

- **D M**, автор и сопровождающий.

## Планы

- Ansible-плейбук для автоматической настройки master и всех slave-нод сразу: inventory с master и списком slave, генерация `.env` и ключей REALITY, регистрация нод и хостов в панели.

История изменений: [CHANGELOG.md](CHANGELOG.md).

## Лицензия

Проект распространяется по лицензии MIT, см. [LICENSE](LICENSE).

Репозиторий содержит только собственные скрипты, конфиги и статические страницы; сторонний код в него не скопирован, а компоненты используются как Docker-образы со своими лицензиями:
- [Marzban](https://github.com/Gozargah/Marzban) и [Marzban Node](https://github.com/Gozargah/Marzban-node): [AGPL-3.0](https://www.gnu.org/licenses/agpl-3.0.html)
- [Xray-core](https://github.com/XTLS/Xray-core): [MPL-2.0](https://www.mozilla.org/MPL/2.0/)
- [Caddy](https://github.com/caddyserver/caddy): [Apache-2.0](https://www.apache.org/licenses/LICENSE-2.0)

## Благодарности

- Команде Gozargah за Marzban и Marzban Node
- Проекту XTLS за Xray и REALITY
- Шаблону README от [PurpleBooth](https://gist.github.com/PurpleBooth/109311bb0361f32d87a2)
