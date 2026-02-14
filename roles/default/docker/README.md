# Ansible Role: Docker

This role installs and configures Docker container runtime on FABRIC cluster nodes.

## Requirements

- Ansible 2.9 or higher
- Supported OS:
  - Rocky Linux 8, 9
  - Ubuntu 20.04 (Focal), 22.04 (Jammy)
  - Debian 11 (Bullseye), 12 (Bookworm)

## Role Variables

### Package Management

```yaml
# Package state (present, latest)
docker_package_state: present
```

### Docker Daemon Configuration

```yaml
# Docker daemon configuration (daemon.json)
docker_daemon_config:
  log-driver: "json-file"
  log-opts:
    max-size: "10m"
    max-file: "3"
  storage-driver: "overlay2"
```

### User Management

```yaml
# Users to add to docker group (allows running docker without sudo)
docker_users:
  - rocky
  - ubuntu
```

### Docker Compose

```yaml
# Install Docker Compose standalone binary
docker_install_compose: true

# Docker Compose version ("latest" or specific version like "v2.24.0")
docker_compose_version: "latest"

# Force reinstall even if already present
docker_compose_force_install: false

# Create symlink at /usr/bin/docker-compose
docker_compose_symlink: true
```

### Advanced Configuration

```yaml
# Enable IPv6 support
docker_enable_ipv6: false

# Enable live restore (keeps containers running during daemon downtime)
docker_live_restore: true

# Enable userland proxy
docker_userland_proxy: true
```

## Dependencies

None.

## Example Playbook

### Basic Installation

```yaml
---
- hosts: all_nodes
  become: true
  roles:
    - role: docker
```

### Custom Configuration

```yaml
---
- hosts: all_nodes
  become: true
  roles:
    - role: docker
      vars:
        docker_users:
          - rocky
          - fabric_user
        docker_daemon_config:
          log-driver: "json-file"
          log-opts:
            max-size: "50m"
            max-file: "5"
          storage-driver: "overlay2"
          insecure-registries:
            - "registry.local:5000"
        docker_install_compose: true
        docker_compose_version: "v2.24.0"
```

### Production Configuration with Custom Registry

```yaml
---
- hosts: nodes_webserver
  become: true
  roles:
    - role: docker
      vars:
        docker_package_state: present
        docker_users:
          - rocky
        docker_daemon_config:
          log-driver: "json-file"
          log-opts:
            max-size: "100m"
            max-file: "10"
          storage-driver: "overlay2"
          max-concurrent-downloads: 3
          max-concurrent-uploads: 5
          default-ulimits:
            nofile:
              soft: 65536
              hard: 65536
          insecure-registries:
            - "registry.fabric.local:5000"
          registry-mirrors:
            - "https://mirror.gcr.io"
```

## Integration with FABRIC Generic Cluster

Add the role to your inventory group variables:

### For all nodes:

```yaml
# inventory/generic_cluster/group_vars/all_nodes.yml
docker_users:
  - "{{ ansible_user }}"
docker_install_compose: true
```

### For specific node types:

```yaml
# inventory/generic_cluster/group_vars/nodes_webserver.yml
docker_daemon_config:
  log-driver: "json-file"
  log-opts:
    max-size: "50m"
    max-file: "5"
  storage-driver: "overlay2"
```

## Post-Installation

After the role runs:

1. Users must log out and back in for docker group membership to take effect
2. Verify installation:
   ```bash
   docker --version
   docker-compose --version
   docker run hello-world
   ```

## Troubleshooting

### Docker daemon fails to start

Check logs:
```bash
sudo journalctl -u docker.service -n 50
```

### Permission denied when running docker

Ensure user is in docker group:
```bash
groups
# Should show 'docker' in the list
```

If not, log out and back in after the playbook runs.

### Docker Compose not found

Verify installation:
```bash
which docker-compose
ls -la /usr/local/bin/docker-compose
```

## License

MIT

## Author Information

Created for FABRIC testbed infrastructure.
