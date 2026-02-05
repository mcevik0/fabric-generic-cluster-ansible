# Base Configuration Roles - Documentation

## Overview

This directory contains fundamental Ansible roles for configuring base system settings across all nodes in the FABRIC cluster. These roles handle essential configurations that should be applied before deploying application-specific services.

## Roles

### 1. common
**Purpose**: Install common packages and apply basic system configurations

**What it does**:
- Sets hostname correctly
- Updates `/etc/hosts` with all cluster nodes
- Installs essential packages (vim, git, wget, curl, net-tools, tcpdump, iperf3, tree, jq, etc.)
- Sets timezone
- Creates common directories
- Configures bash aliases
- Basic firewall setup (optional)

**Tags**: `common`, `hostname`, `hosts`, `packages`, `services`, `timezone`, `directories`, `aliases`

**Key Variables**:
```yaml
update_hosts_file: true              # Update /etc/hosts with cluster nodes
configure_firewall: false            # Enable basic firewall configuration
timezone: "America/New_York"         # System timezone
common_directories:                  # Directories to create
  - /opt/scripts
  - /opt/logs
  - /opt/backups
```

### 2. timesync
**Purpose**: Configure time synchronization using chrony/NTP

**What it does**:
- Uses `fedora.linux_system_roles.timesync` for all systems
- Configures chrony (preferred) or NTP daemon
- Verifies time synchronization status
- Works on both RedHat and Debian-based systems

**Tags**: `timesync`, `verify`

**Key Variables**:
```yaml
ntp_servers:
  - hostname: 0.pool.ntp.org
    iburst: yes
  - hostname: 1.pool.ntp.org
    iburst: yes
ntp_provider: "chrony"               # chrony or ntp
timesync_enabled: true
```

### 3. system_updates
**Purpose**: Update system packages and handle reboots if needed

**What it does**:
- Updates all packages (or specific packages)
- Handles both RedHat (dnf) and Debian (apt) systems
- Checks if reboot is required
- Optionally performs reboot if allowed
- Cleans package cache
- Removes unused dependencies (Debian)

**Tags**: `updates`, `reboot`

**Key Variables**:
```yaml
update_all_packages: true            # Update all packages
allow_reboot: false                  # Allow automatic reboot
apt_upgrade_type: "dist"             # For Debian: safe, full, or dist
autoremove: true                     # Remove unused packages (Debian)
clean_cache: false                   # Clean package cache
packages_to_update: []               # Specific packages (if not updating all)
```

### 4. selinux
**Purpose**: Configure SELinux (RedHat systems only)

**What it does**:
- Uses `fedora.linux_system_roles.selinux`
- Sets SELinux mode (enforcing, permissive, disabled)
- Configures SELinux policy
- Manages booleans, file contexts, and port contexts
- Verifies SELinux status

**Tags**: `selinux`, `verify`

**Key Variables**:
```yaml
selinux_target_state: "enforcing"    # enforcing, permissive, or disabled
selinux_target_policy: "targeted"    # targeted or mls
selinux_custom_booleans: []          # Custom boolean settings
selinux_custom_fcontexts: []         # Custom file contexts
selinux_custom_ports: []             # Custom port contexts
```

**Example custom configurations**:
```yaml
selinux_custom_booleans:
  - name: httpd_can_network_connect
    state: on
    persistent: yes

selinux_custom_fcontexts:
  - target: '/opt/myapp(/.*)?'
    setype: httpd_sys_content_t
    state: present

selinux_custom_ports:
  - ports: '8080'
    proto: tcp
    setype: http_port_t
    state: present
```

### 5. firewall
**Purpose**: Configure system firewall

**What it does**:
- RedHat: Uses `fedora.linux_system_roles.firewall` with firewalld
- Debian: Uses UFW (Uncomplicated Firewall)
- Allows specified services and ports
- Manages trusted sources
- Verifies firewall status

**Tags**: `firewall`, `verify`

**Key Variables**:
```yaml
firewall_enabled: true
firewall_default_zone: "public"      # RedHat only
firewall_allowed_services:
  - ssh
  - dhcpv6-client
firewall_allowed_ports:
  - port: 8080
    protocol: tcp
firewall_trusted_sources:
  - 10.0.0.0/8
  - 192.168.1.0/24
firewall_blocked_services: []
firewall_logging_level: "low"        # Debian only
```

## Directory Structure

```
roles/default/
├── common/
│   ├── defaults/
│   │   └── main.yml
│   ├── handlers/
│   │   └── main.yml
│   ├── tasks/
│   │   ├── main.yml
│   │   └── firewall.yml
│   └── vars/
│       ├── RedHat.yml
│       └── Debian.yml
├── timesync/
│   ├── defaults/
│   │   └── main.yml
│   └── tasks/
│       └── main.yml
├── system_updates/
│   ├── defaults/
│   │   └── main.yml
│   └── tasks/
│       ├── main.yml
│       ├── RedHat.yml
│       └── Debian.yml
├── selinux/
│   ├── defaults/
│   │   └── main.yml
│   └── tasks/
│       └── main.yml
└── firewall/
    ├── defaults/
    │   └── main.yml
    └── tasks/
        ├── main.yml
        ├── RedHat.yml
        ├── Debian.yml
        └── verify.yml
```

## Usage

### Prerequisites

1. Install required collections and roles:
```bash
cd ~/ansible
ansible-galaxy install -r requirements.yml
```

### Running the Base Configuration

**Option 1: Run all base configurations**
```bash
ansible-playbook playbooks/default/site.yml
```

**Option 2: Run base configuration playbook only**
```bash
ansible-playbook playbooks/default/playbook_base_config.yml
```

**Option 3: Run specific roles with tags**
```bash
# Install common packages only
ansible-playbook playbooks/default/playbook_base_config.yml --tags common

# Configure time sync only
ansible-playbook playbooks/default/playbook_base_config.yml --tags timesync

# Update packages only
ansible-playbook playbooks/default/playbook_base_config.yml --tags updates

# Configure SELinux only (RedHat systems)
ansible-playbook playbooks/default/playbook_base_config.yml --tags selinux

# Configure firewall only
ansible-playbook playbooks/default/playbook_base_config.yml --tags firewall
```

**Option 4: Run on specific hosts**
```bash
# Run on single host
ansible-playbook playbooks/default/playbook_base_config.yml -l lc-10

# Run on specific site
ansible-playbook playbooks/default/playbook_base_config.yml -l site_DALL

# Run on specific OS type
ansible-playbook playbooks/default/playbook_base_config.yml -l os_rocky
```

### Controlling Role Execution

Use variables to control which roles run:

```bash
# Skip updates
ansible-playbook playbooks/default/playbook_base_config.yml -e "perform_updates=false"

# Skip timesync
ansible-playbook playbooks/default/playbook_base_config.yml -e "configure_timesync=false"

# Skip SELinux configuration
ansible-playbook playbooks/default/playbook_base_config.yml -e "configure_selinux=false"

# Enable firewall configuration
ansible-playbook playbooks/default/playbook_base_config.yml -e "configure_firewall=true"

# Allow automatic reboot after updates
ansible-playbook playbooks/default/playbook_base_config.yml -e "allow_reboot=true"
```

### Check Mode (Dry Run)

```bash
# See what would change without making changes
ansible-playbook playbooks/default/playbook_base_config.yml --check

# Check with diff output
ansible-playbook playbooks/default/playbook_base_config.yml --check --diff
```

## Customization

### Per-Site Customization

Add role-specific variables to site group_vars:

**inventory/default/group_vars/site_DALL.yml**:
```yaml
# Custom NTP servers for DALL site
ntp_servers:
  - hostname: ntp.dall.example.com
    iburst: yes
  - hostname: 0.pool.ntp.org
    iburst: yes

# Trusted networks for DALL site
firewall_trusted_sources:
  - 10.133.130.0/24

# Custom timezone
timezone: "America/Chicago"
```

### Per-Host Customization

Add role-specific variables to host_vars:

**inventory/default/host_vars/lc-10.yml**:
```yaml
# Don't allow automatic reboot on this host
allow_reboot: false

# Custom firewall rules for load balancer
firewall_allowed_ports:
  - port: 80
    protocol: tcp
  - port: 443
    protocol: tcp
  - port: 8404
    protocol: tcp

# Additional services
firewall_allowed_services:
  - ssh
  - http
  - https
```

### Per-OS Customization

OS-specific variables are automatically loaded from `vars/RedHat.yml` or `vars/Debian.yml` in the common role.

## Examples

### Example 1: Initial Cluster Setup

```bash
# Full base configuration on all nodes
ansible-playbook playbooks/default/site.yml
```

This will:
1. Install common packages
2. Update all packages
3. Configure time synchronization
4. Configure SELinux (RedHat only)
5. Optionally configure firewall

### Example 2: Update Packages Only

```bash
# Update packages on all nodes
ansible-playbook playbooks/default/playbook_base_config.yml --tags updates

# Update with automatic reboot if needed
ansible-playbook playbooks/default/playbook_base_config.yml --tags updates -e "allow_reboot=true"
```

### Example 3: Configure Firewall on Webservers

```bash
# Enable firewall on webserver nodes
ansible-playbook playbooks/default/playbook_base_config.yml \
  -l nodes_webserver \
  --tags firewall \
  -e "configure_firewall=true"
```

### Example 4: Selective Package Updates

```bash
# Update specific packages only
ansible-playbook playbooks/default/playbook_base_config.yml \
  --tags updates \
  -e "update_all_packages=false" \
  -e '{"packages_to_update": ["vim", "git", "curl"]}'
```

### Example 5: Configure SELinux Booleans

Add to group_vars or host_vars:
```yaml
selinux_custom_booleans:
  - name: httpd_can_network_connect
    state: on
    persistent: yes
  - name: httpd_can_network_connect_db
    state: on
    persistent: yes
```

Then run:
```bash
ansible-playbook playbooks/default/playbook_base_config.yml --tags selinux
```

## Troubleshooting

### Time Sync Issues

```bash
# Check current time sync status
ansible all_nodes -m command -a "timedatectl status"

# Verify chrony is running
ansible all_nodes -m systemd -a "name=chronyd state=started"

# Check chrony sources
ansible all_nodes -m command -a "chronyc sources"
```

### Firewall Issues

```bash
# Check firewall status on RedHat
ansible os_rocky -m command -a "firewall-cmd --state"
ansible os_rocky -m command -a "firewall-cmd --list-all"

# Check firewall status on Debian
ansible os_debian,os_ubuntu -m command -a "ufw status verbose"
```

### SELinux Issues

```bash
# Check SELinux status
ansible os_rocky -m command -a "getenforce"

# Check SELinux denials
ansible os_rocky -m command -a "ausearch -m avc -ts recent"

# Set to permissive temporarily for troubleshooting
ansible os_rocky -m command -a "setenforce 0" -b
```

### Package Update Issues

```bash
# Check for failed transactions (RedHat)
ansible os_rocky -m command -a "dnf history"

# Check for held packages (Debian)
ansible os_debian,os_ubuntu -m command -a "apt-mark showhold"

# Clear cache and retry
ansible-playbook playbooks/default/playbook_base_config.yml \
  --tags updates \
  -e "clean_cache=true"
```

## Best Practices

1. **Always run in check mode first** on production systems
2. **Test on a single node** before running on all nodes
3. **Schedule updates** during maintenance windows
4. **Use tags** to run only what you need
5. **Document customizations** in group_vars/host_vars
6. **Keep roles modular** - don't modify role defaults, use group_vars
7. **Monitor logs** after applying configurations
8. **Backup configurations** before making changes

## Dependencies

### Required Collections
- `community.general`
- `ansible.posix`

### Required Roles
- `fedora.linux_system_roles.timesync`
- `fedora.linux_system_roles.selinux`
- `fedora.linux_system_roles.firewall`

Install with:
```bash
ansible-galaxy install -r requirements.yml
```

## Notes

- **SELinux role** only runs on RedHat-based systems
- **Firewall role** uses different backends (firewalld vs UFW) based on OS
- **Time sync role** works on all systems using linux-system-roles
- **System updates** handles package manager differences automatically
- **Reboot handling** requires `allow_reboot=true` to actually reboot systems

## Support

For issues or questions:
1. Check the role's tasks files for detailed implementation
2. Review variables in defaults/ and vars/ directories
3. Run with `-vvv` flag for verbose output
4. Check logs in /var/log/
