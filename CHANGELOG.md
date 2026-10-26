# Журнал изменений

Все заметные изменения проекта записываются в этот файл.

Формат основан на [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/), проект придерживается [семантического версионирования](https://semver.org/lang/ru/).

## [Unreleased]

### Запланировано
- Ansible-плейбук для автоматической настройки master и всех slave-нод сразу: inventory с master и списком slave, генерация `.env` и ключей REALITY, регистрация нод и хостов в панели.

## [0.1.0] - 2026-10-26

### Добавлено
- Master: панель Marzban v0.8.4 и ядро Xray в Docker Compose (образ закреплён по digest), панель только на `127.0.0.1:2053` с самоподписанным сертификатом, доступ через SSH-туннель.
- Инбаунд VLESS TCP REALITY с XTLS Vision и self-steal: fallback на свой сайт-заглушку `127.0.0.1:8443`, подписки через `/sub/*`.
- Генерация секретов и ключей REALITY (`make master-secrets`), рендер `xray_config.json` из шаблона с сохранением клиентов, настройка SNI хостов через API, проверка API (`make master-probe`).
- Slave: Marzban Node v0.5.2 (REST) и Caddy 2.10 с сайтом-заглушкой и ACME, установка `make slave-cert` + `make slave-install`.
- Инбаунд ноды на порту 8444: публичный `:443` на `PUBLIC_IP` перенаправляется на `:8444`, на master `:8444` закрыт снаружи; фаервол для 62050/62051 только с master и `node2-firewall.service` для автозагрузки.
- Несколько серверов в одной подписке; новые инбаунды автоматически включаются у всех пользователей.
- Необязательный хук `MASTER_PRE_INSTALL` и локальные `local/` + `local.mk` для настроек конкретного сервера.
- Документация на русском в `docs/`: быстрый старт с покупки VPS, добавление ноды, самопроверка, архитектура, конфигурация, эксплуатация, решение проблем, FAQ, предупреждения.
- README по шаблону PurpleBooth, CONTRIBUTING, CODE_OF_CONDUCT (Contributor Covenant 2.1), SECURITY, лицензия MIT, `.editorconfig`, шаблоны issues и pull request.
- Файлы для ИИ-ассистентов: AGENTS.md, CLAUDE.md, `.github/copilot-instructions.md`, `.cursor/rules/project.mdc`, `llms.txt`.

[Unreleased]: https://github.com/imtrim/marzban-vless-cluster/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/imtrim/marzban-vless-cluster/releases/tag/v0.1.0
