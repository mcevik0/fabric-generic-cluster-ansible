# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Ansible automation for managing [FABRIC](https://fabric-testbed.net/) cluster nodes — base OS configuration and an optional monitoring stack (Prometheus + Grafana + Node Exporter + cAdvisor). Targets heterogeneous nodes running Rocky Linux, Ubuntu, or Debian across multiple FABRIC sites.

## Setup

Install required Galaxy collections:
```bash
bash install_requirements.sh
# or manually:
ansible-galaxy collection install -r requirements.yml
```

`ansible.cfg` expects the inventory and roles at `~/ansible/inventory/default/hosts` and `~/ansible/roles/default`. The `scripts/slice_integrate.sh` creates these symlinks for a given FABRIC slice.

## Common Commands

```bash
# Full cluster configuration
ansible-playbook playbooks/default/site.yml

# Base OS setup only
ansible-playbook playbooks/default/playbook_base_config.yml

# Deploy/update monitoring stack
ansible-playbook playbooks/default/playbook_monitoring.yml

# Limit to specific hosts or groups
ansible-playbook playbooks/default/site.yml --limit lc-10
ansible-playbook playbooks/default/site.yml --limit role_monitoring

# Target specific roles via tags
ansible-playbook playbooks/default/site.yml --tags docker
ansible-playbook playbooks/default/site.yml --tags prometheus,grafana

# Dry run
ansible-playbook playbooks/default/site.yml --check

# Debug/variable verification (opt-in, tagged never by default)
ansible-playbook playbooks/default/playbook_debug.yml --tags debug
ansible-playbook playbooks/default/verify_variables.yml

# Ad-hoc commands
ansible all_nodes -m ping
ansible all_nodes -m setup --limit lc-10
```

## Architecture

### Playbook Hierarchy

`site.yml` imports all other playbooks in order:
1. `playbook_base_config.yml` — applies common, system_updates, timesync, selinux, firewall, docker to `all_nodes`
2. `playbook_monitoring.yml` — deploys node_exporter and cadvisor to `all_nodes`; prometheus and grafana to `role_monitoring`

### Inventory Structure (`inventory/default/`)

Nodes belong to three orthogonal group types that combine via `group_vars`:

| Group type | Examples | Purpose |
|---|---|---|
| `os_*` | `os_rocky`, `os_ubuntu`, `os_debian` | OS-specific package names and behavior |
| `site_*` | `site_DALL`, `site_LOSA`, `site_SALT` | Site-specific network/config overrides |
| `role_*` | `role_monitoring`, `role_webserver`, `role_database`, `role_loadbalancer` | Service assignments |

Variable precedence (lowest → highest): `all_nodes.yml` → `os_*.yml` / `site_*.yml` / `role_*.yml` → `host_vars/<host>.yml`

### Roles (`roles/default/`)

| Role | What it does |
|---|---|
| `common` | Hostname, `/etc/hosts`, base packages, timezone, bash aliases |
| `system_updates` | `dnf`/`apt` updates with reboot handling |
| `timesync` | NTP via `fedora.linux_system_roles.timesync` |
| `selinux` | SELinux config (RedHat only) via `fedora.linux_system_roles.selinux` |
| `firewall` | `firewalld` (RedHat) or UFW (Debian) via `fedora.linux_system_roles.firewall` |
| `docker` | Docker daemon + Docker Compose, multi-OS |
| `node_exporter` | Prometheus node metrics agent (systemd service) |
| `cadvisor` | Google cAdvisor container metrics (Docker) |
| `prometheus` | Prometheus TSDB (Docker Compose) |
| `grafana` | Grafana + provisioned dashboards (Docker Compose) |
| `debug` | Debug tasks, opt-in via `--tags debug` |

### Key Variable Conventions

- `all_nodes.yml` sets the canonical defaults (NTP servers, timezone, package lists, monitoring ports).
- OS-specific vars override package manager commands and package names.
- `host_vars/<host>.yml` holds hardware metadata, FQDN, maintenance windows, and per-node service lists — not used to override role behavior directly.
- Monitoring target scrape configs are built from inventory group membership and `group_vars/role_monitoring.yml`.

### External Galaxy Dependencies

- `community.general` ≥ 8.0.0
- `ansible.posix` ≥ 1.5.0
- `fedora.linux_system_roles` ≥ 1.0.0 (used by timesync, selinux, firewall roles)
