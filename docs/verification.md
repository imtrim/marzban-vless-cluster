# Самопроверка

Проверяйте слои снизу вверх. Команды с пометкой *(master)* / *(slave)* выполняются на этом сервере, *(снаружи)* — с вашего компьютера.

## 1. DNS
*(снаружи)*
```bash
dig +short <master_domain>    # -> <ip_master>
dig +short <slave_domain>     # -> <ip_slave>
```

## 2. Контейнеры
*(master)* `make master-status` → `marzban` в состоянии `Up`.
*(slave)* `make slave-status` → `marzban-node` и `node2-caddy` в состоянии `Up`.
Или на любом сервере: `docker ps --format '{{.Names}} {{.Status}}'`.

## 3. Слушающие порты
*(master)*
```bash
ss -lntp | grep -E ':(80|443|2053|8443|8444) '
```
Ожидается: `xray` на `0.0.0.0:443` и `:8444`; панель на `127.0.0.1:2053`; ваш веб-сервер на `127.0.0.1:8443` и `:80`.

*(slave)* `make slave-status` печатает тот же фильтр для `80|443|8443|8444|62050|62051`: `xray` на :8444 (и :443), API ноды на 62050/62051, Caddy на `127.0.0.1:8443` и :80.

## 4. Фаервол
*(slave)*
```bash
iptables -t nat -S PREROUTING | grep REDIRECT
# -A PREROUTING -d <ip_slave>/32 -p tcp -m tcp --dport 443 -j REDIRECT --to-ports 8444
iptables -S INPUT | grep -E '62050|62051|8444'
systemctl is-enabled node2-firewall.service   # enabled
```
*(снаружи)*
```bash
nc -vz -w 5 <ip_slave> 62050    # должен быть таймаут
nc -vz -w 5 <ip_master> 8444    # должен быть таймаут
nc -vz -w 5 <ip_master> 2053    # должна быть ошибка
```
*(master)* `nc -vz -w 5 <ip_slave> 62050` → succeeded (master разрешён).

## 5. Сайт-заглушка (fallback REALITY)
Обычный HTTPS-запрос без VPN-ключей должен получить сайт-заглушку с валидным сертификатом:
*(снаружи)*
```bash
curl -sI https://<master_domain>/ | head -1    # HTTP/2 200
curl -sI https://<slave_domain>/  | head -1    # HTTP/2 200
```
Напрямую к внутреннему сайту: *(master)* `make master-status` → `caddy-<master_domain> 200`, `public-<master_domain> 200`; *(slave)* `make slave-status` → `cover via caddy 200`.

## 6. Параметры REALITY
*(master)* `make master-status` печатает `Reality publicKey`, `shortId`, `SNI`, `address`. Они должны совпадать со ссылкой в подписке (`pbk=`, `sid=`, `sni=`). Для ноды — с `NODE2_REALITY_PUBLIC_KEY` / `NODE2_REALITY_SHORT_ID` и `<slave_domain>`.
Отрендеренный конфиг: `python3 -m json.tool /var/lib/marzban/xray_config.json | grep -E '"tag"|"port"|serverNames' -A1`.

## 7. TLS-рукопожатие выглядит как у сайта-заглушки
*(снаружи)*
```bash
openssl s_client -connect <ip_master>:443 -servername <master_domain> </dev/null 2>/dev/null | grep -E 'subject=|issuer='
```
Ожидается настоящий сертификат `<master_domain>` (например, Let's Encrypt). То же для `<ip_slave>` / `<slave_domain>`.

## 8. Панель и API
*(master)*
```bash
make master-probe
```
Ожидается: `created user probe` (или `keep existing user probe`), `status active`, `disabled probe disabled`, `enabled probe active` и ссылка `vless://`. Потом удалите `probe` в панели, если он не нужен.

## 9. URL подписки
*(снаружи)*
```bash
curl -s https://<master_domain>/sub/<token> | base64 -d
```
Ожидается по строке `vless://` на каждый хост: `…@<ip_master>:443?…sni=<master_domain>…` и при наличии slave `…@<ip_slave>:443?…sni=<slave_domain>…`, везде `security=reality`, `flow=xtls-rprx-vision`. Неверный токен возвращает `{"detail":"Not Found"}` — это тоже доказывает, что `/sub/*` доходит до Marzban.

## 10. Нода подключена
Панель → **Nodes**: статус **connected**, видна версия Xray. Если `error`, см. [Решение проблем](troubleshooting.md).

## 11. Проверка клиентом
Импортируйте подписку в клиент, по очереди выберите каждый сервер и откройте `https://ifconfig.me`: должен показаться `<ip_master>` и `<ip_slave>` соответственно. Счётчик трафика пользователя в панели растёт.

## 12. Логи
```bash
make master-logs                    # (master) логи Marzban и ядра Xray, Ctrl-C для выхода
make slave-logs                     # (slave) marzban-node + Caddy
docker logs --tail=100 node2-caddy  # (slave) проблемы ACME / сертификата
```
