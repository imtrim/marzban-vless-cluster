# marzban-vless-cluster — Marzban + VLESS/REALITY on several servers.
# master-* targets run on the panel server, slave-* on each node.
ROOT   := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
M      := $(ROOT)/master
S      := $(ROOT)/slave
S_COMPOSE := docker compose -f $(S)/compose.yml --env-file $(S)/.env

# Optional script run by master-install before Marzban starts (e.g. set it in local.mk).
MASTER_PRE_INSTALL ?=
# Untracked local overrides/hooks.
-include $(ROOT)/local.mk

.PHONY: help master-install master-start master-stop master-restart master-logs master-status \
	master-secrets master-hosts master-probe slave-cert slave-firewall slave-install slave-up \
	slave-down slave-logs slave-status

help:
	@echo "master (panel):"
	@echo "  make master-install | master-start | master-stop | master-restart"
	@echo "  make master-logs | master-status | master-secrets | master-hosts | master-probe"
	@echo "slave (Marzban Node):"
	@echo "  make slave-cert      paste panel node certificate (stdin)"
	@echo "  make slave-firewall  62050/62051 only from master; PUBLIC_IP:443 -> 8444"
	@echo "  make slave-install   firewall + boot unit + marzban-node + caddy cover"
	@echo "  make slave-up | slave-down | slave-logs | slave-status"

master-install: ; MASTER_PRE_INSTALL='$(MASTER_PRE_INSTALL)' $(M)/scripts/install.sh
master-start:   ; $(M)/scripts/start.sh
master-stop:    ; $(M)/scripts/stop.sh
master-restart: master-stop master-start
master-logs:    ; $(M)/scripts/logs.sh
master-status:  ; $(M)/scripts/status.sh
master-secrets: ; $(M)/scripts/setup-secrets.sh
master-hosts:   ; $(M)/scripts/configure-hosts.sh
master-probe:   ; $(M)/scripts/probe-user.sh

slave-cert:
	@mkdir -p /var/lib/marzban-node
	@echo "paste the certificate from panel -> Nodes, then Ctrl-D:"
	@cat > /var/lib/marzban-node/ssl_client_cert.pem
	@chmod 600 /var/lib/marzban-node/ssl_client_cert.pem
	@grep -q "BEGIN CERTIFICATE" /var/lib/marzban-node/ssl_client_cert.pem && echo saved

slave-firewall: ; $(S)/scripts/firewall.sh
slave-install:  ; $(S)/scripts/install.sh
slave-up:       ; $(S_COMPOSE) up -d
slave-down:     ; $(S_COMPOSE) down
slave-logs:     ; $(S_COMPOSE) logs -f --tail=100
slave-status:   ; $(S)/scripts/status.sh
