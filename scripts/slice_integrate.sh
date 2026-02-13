#!/bin/bash
# slice_integrate.sh
# Integrate FABRIC slice with fabric-generic-cluster-ansible repository
#
# Usage: ./slice_integrate.sh <slice_name>
#
# This script should be run on the ansible control node after ansible_setup.py completes
# It assumes:
#   - ~/ansible/ directory exists with inventory/hosts
#   - fabric-generic-cluster-ansible will be cloned to ~/

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
ANSIBLE_DIR="${HOME}/ansible"
REPO_URL="https://github.com/mcevik0/fabric-generic-cluster-ansible.git"
REPO_DIR="${HOME}/fabric-generic-cluster-ansible"
ORIGINAL_INVENTORY="${ANSIBLE_DIR}/inventory/hosts"

# Functions
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_step() {
    echo -e "\n${YELLOW}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

# Check if slice name provided
if [ -z "$1" ]; then
    print_error "Slice name required!"
    echo ""
    echo "Usage: $0 <slice_name>"
    echo ""
    echo "Example:"
    echo "  $0 my-experiment-123"
    exit 1
fi

SLICE_NAME="$1"

print_header "FABRIC Slice Integration: ${SLICE_NAME}"

# Validate prerequisites
print_step "Validating prerequisites..."

if [ ! -d "${ANSIBLE_DIR}" ]; then
    print_error "Ansible directory not found: ${ANSIBLE_DIR}"
    echo "Please ensure ansible_setup.py has been run first."
    exit 1
fi

if [ ! -f "${ORIGINAL_INVENTORY}" ]; then
    print_error "Original inventory not found: ${ORIGINAL_INVENTORY}"
    echo "Please ensure ansible_setup.py has been run first."
    exit 1
fi

print_success "Prerequisites validated"

# Clone or update repository
print_step "Setting up fabric-generic-cluster-ansible repository..."

if [ -d "${REPO_DIR}" ]; then
    print_info "Repository already exists, updating..."
    cd "${REPO_DIR}"
    git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || true
    print_success "Repository updated"
else
    print_info "Cloning repository to ${REPO_DIR}..."
    git clone "${REPO_URL}" "${REPO_DIR}"
    print_success "Repository cloned"
fi

# Check if reference inventory exists
if [ ! -d "${REPO_DIR}/inventory/default" ]; then
    print_error "Reference inventory not found in repository"
    echo "Expected: ${REPO_DIR}/inventory/default"
    exit 1
fi

# Create slice-specific directory structure
print_step "Creating slice-specific directory structure..."

SLICE_INVENTORY_DIR="${ANSIBLE_DIR}/inventory/${SLICE_NAME}"
SLICE_PLAYBOOKS_DIR="${ANSIBLE_DIR}/playbooks/${SLICE_NAME}"
SLICE_ROLES_DIR="${ANSIBLE_DIR}/roles/${SLICE_NAME}"

# Check if slice directories already exist
if [ -d "${SLICE_INVENTORY_DIR}" ] || [ -d "${SLICE_PLAYBOOKS_DIR}" ] || [ -d "${SLICE_ROLES_DIR}" ]; then
    print_error "Slice directories already exist for: ${SLICE_NAME}"
    read -p "Do you want to overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborting."
        exit 1
    fi
    rm -rf "${SLICE_INVENTORY_DIR}" "${SLICE_PLAYBOOKS_DIR}" "${SLICE_ROLES_DIR}"
fi

# Create directories
mkdir -p "${SLICE_INVENTORY_DIR}"/{group_vars,host_vars}
mkdir -p "${SLICE_PLAYBOOKS_DIR}"
mkdir -p "${SLICE_ROLES_DIR}"

print_success "Directory structure created"

# Move original inventory into slice directory
print_step "Organizing inventory..."

if [ -f "${ORIGINAL_INVENTORY}" ]; then
    mv "${ORIGINAL_INVENTORY}" "${SLICE_INVENTORY_DIR}/hosts"
    print_success "Inventory moved to slice directory"
else
    print_error "Original inventory not found"
    exit 1
fi

# Copy and customize group_vars from reference
print_step "Setting up group_vars..."

if [ -d "${REPO_DIR}/inventory/default/group_vars" ]; then
    # Copy all group_vars except site templates
    for gvar_file in "${REPO_DIR}/inventory/default/group_vars"/*.yml; do
        filename=$(basename "$gvar_file")
        
        # Skip site_TEMPLATE.yml
        if [ "$filename" != "site_TEMPLATE.yml" ]; then
            cp "$gvar_file" "${SLICE_INVENTORY_DIR}/group_vars/"
            print_info "  Copied: ${filename}"
        fi
    done
    
    # Generate site-specific group_vars from template
    print_info "Generating site-specific group_vars..."
    
    # Extract unique sites from inventory
    sites=$(grep '^\[site_' "${SLICE_INVENTORY_DIR}/hosts" | tr -d '[]' | sed 's/site_//' | sort -u)
    
    if [ -n "$sites" ]; then
        for site in $sites; do
            if [ -f "${REPO_DIR}/inventory/default/group_vars/site_TEMPLATE.yml" ]; then
                # Generate site-specific file from template
                sed -e "s/SITE_NAME_PLACEHOLDER/${site}/g" \
                    -e "s/SITE_CODE_PLACEHOLDER/${site}/g" \
                    "${REPO_DIR}/inventory/default/group_vars/site_TEMPLATE.yml" \
                    > "${SLICE_INVENTORY_DIR}/group_vars/site_${site}.yml"
                
                print_info "  Generated: site_${site}.yml"
            else
                print_info "  Template not found, creating minimal site_${site}.yml"
                cat > "${SLICE_INVENTORY_DIR}/group_vars/site_${site}.yml" << EOF
---
# Site variables for ${site}
site_name: "${site}"
site_code: "${site}"
EOF
            fi
        done
    else
        print_info "  No sites found in inventory"
    fi
    
    print_success "Group variables configured"
else
    print_error "Reference group_vars not found"
fi

# Clean up old directory structure
print_step "Cleaning up old directories..."

if [ -d "${ANSIBLE_DIR}/group_vars" ]; then
    rm -rf "${ANSIBLE_DIR}/group_vars"
    print_success "Removed old group_vars directory"
fi

if [ -d "${ANSIBLE_DIR}/host_vars" ]; then
    rm -rf "${ANSIBLE_DIR}/host_vars"
    print_success "Removed old host_vars directory"
fi

# Generate host_vars based on inventory
print_step "Generating host_vars..."

# Extract hostnames from inventory
hostnames=$(grep "ansible_host=" "${SLICE_INVENTORY_DIR}/hosts" | awk '{print $1}' | sort -u)

if [ -z "$hostnames" ]; then
    print_error "No hosts found in inventory"
    exit 1
fi

host_count=0
for hostname in $hostnames; do
    # Check if reference host_vars exists
    if [ -f "${REPO_DIR}/inventory/default/host_vars/${hostname}.yml" ]; then
        # Copy reference if exists
        cp "${REPO_DIR}/inventory/default/host_vars/${hostname}.yml" "${SLICE_INVENTORY_DIR}/host_vars/"
        print_info "  Copied reference: ${hostname}.yml"
    else
        # Create minimal host_vars from template
        cat > "${SLICE_INVENTORY_DIR}/host_vars/${hostname}.yml" << EOF
---
# host_vars/${hostname}.yml
# Host-specific variables for ${hostname}

# Host identification
hostname: "${hostname}"
fqdn: "${hostname}.fabric.net"

# Add host-specific overrides here
EOF
        print_info "  Generated: ${hostname}.yml"
    fi
    host_count=$((host_count + 1)) 
done

print_success "Generated host_vars for ${host_count} host(s)"

# Create symlinks for roles
print_step "Creating role symlinks..."

if [ -d "${REPO_DIR}/roles/default" ]; then
    role_count=0
    for role_path in "${REPO_DIR}/roles/default"/*; do
        if [ -d "$role_path" ]; then
            role_name=$(basename "$role_path")
            ln -sf "${role_path}" "${SLICE_ROLES_DIR}/${role_name}"
            print_info "  Linked: ${role_name}"
            ((role_count++))
        fi
    done
    print_success "Created ${role_count} role symlink(s)"
else
    print_error "Default roles not found in repository"
fi

# Create symlinks for playbooks
print_step "Creating playbook symlinks..."

if [ -d "${REPO_DIR}/playbooks/default" ]; then
    playbook_count=0
    for playbook_path in "${REPO_DIR}/playbooks/default"/*.yml; do
        if [ -f "$playbook_path" ]; then
            playbook_name=$(basename "$playbook_path")
            ln -sf "${playbook_path}" "${SLICE_PLAYBOOKS_DIR}/${playbook_name}"
            print_info "  Linked: ${playbook_name}"
            ((playbook_count++))
        fi
    done
    print_success "Created ${playbook_count} playbook symlink(s)"
else
    print_error "Default playbooks not found in repository"
fi

# Copy requirements.yml and install script if they exist
print_step "Setting up additional files..."

if [ -f "${REPO_DIR}/requirements.yml" ]; then
    cp "${REPO_DIR}/requirements.yml" "${ANSIBLE_DIR}/"
    print_success "requirements.yml copied"
fi

if [ -f "${REPO_DIR}/install_requirements.sh" ]; then
    cp "${REPO_DIR}/install_requirements.sh" "${ANSIBLE_DIR}/"
    chmod +x "${ANSIBLE_DIR}/install_requirements.sh"
    print_success "install_requirements.sh copied"
fi

# Update ansible.cfg
print_step "Updating ansible.cfg..."

# Backup original ansible.cfg
if [ -f "${ANSIBLE_DIR}/ansible.cfg" ]; then
    cp "${ANSIBLE_DIR}/ansible.cfg" "${ANSIBLE_DIR}/ansible.cfg.backup"
    print_info "Original ansible.cfg backed up"
fi

# Create new ansible.cfg
cat > "${ANSIBLE_DIR}/ansible.cfg" << EOF
[defaults]
inventory = ${ANSIBLE_DIR}/inventory/${SLICE_NAME}/hosts
roles_path = ${ANSIBLE_DIR}/roles/${SLICE_NAME}
host_key_checking = False
retry_files_enabled = False
gathering = smart
fact_caching = jsonfile
fact_caching_connection = ${ANSIBLE_DIR}/.ansible_cache
fact_caching_timeout = 86400

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False

[ssh_connection]
pipelining = True
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no
EOF

print_success "ansible.cfg updated for slice: ${SLICE_NAME}"

# Create slice metadata
print_step "Creating slice metadata..."

cat > "${ANSIBLE_DIR}/inventory/${SLICE_NAME}/SLICE_INFO.txt" << EOF
Slice Name: ${SLICE_NAME}
Created: $(date)
Control Node: $(hostname)
Repository: ${REPO_URL}
Repository Location: ${REPO_DIR}

Directory Structure:
  inventory/${SLICE_NAME}/     - Slice-specific inventory and variables
  playbooks/${SLICE_NAME}/     - Symlinked playbooks
  roles/${SLICE_NAME}/         - Symlinked roles

To update from repository:
  cd ${REPO_DIR} && git pull

To switch to different slice:
  Edit ansible.cfg to point to different slice directories
EOF

print_success "Metadata created"

# Create README for the slice
cat > "${ANSIBLE_DIR}/inventory/${SLICE_NAME}/README.md" << EOF
# FABRIC Slice: ${SLICE_NAME}

## Overview
This directory contains inventory and variables for FABRIC slice \`${SLICE_NAME}\`.

## Created
$(date)

## Directory Structure
\`\`\`
inventory/${SLICE_NAME}/
├── hosts              # Inventory from FABRIC slice
├── group_vars/        # Group-specific variables
│   ├── all_nodes.yml
│   ├── nodes_*.yml
│   ├── os_*.yml
│   └── site_*.yml
└── host_vars/         # Host-specific variables
    ├── lc-10.yml
    ├── lc-20.yml
    └── ...
\`\`\`

## Customization

### Modify group variables
Edit files in \`group_vars/\`:
\`\`\`bash
vim group_vars/all_nodes.yml
vim group_vars/nodes_webserver.yml
\`\`\`

### Modify host variables
Edit files in \`host_vars/\`:
\`\`\`bash
vim host_vars/lc-10.yml
\`\`\`

## Usage

All ansible commands should be run from the ansible directory:

\`\`\`bash
cd ${ANSIBLE_DIR}
source venv/bin/activate

# Test connectivity
ansible all_nodes -m ping

# Run playbooks
ansible-playbook playbooks/${SLICE_NAME}/site.yml

# Run specific roles
ansible-playbook playbooks/${SLICE_NAME}/playbook_base_config.yml --tags common
\`\`\`

## Notes
- Playbooks are symlinked from: \`${REPO_DIR}/playbooks/default/\`
- Roles are symlinked from: \`${REPO_DIR}/roles/default/\`
- To update from repository: \`cd ${REPO_DIR} && git pull\`
EOF

print_success "README created"

# Display summary
print_header "Integration Complete!"

echo ""
echo -e "${CYAN}Slice Information:${NC}"
echo -e "  Name: ${YELLOW}${SLICE_NAME}${NC}"
echo -e "  Inventory: ${YELLOW}${SLICE_INVENTORY_DIR}${NC}"
echo -e "  Playbooks: ${YELLOW}${SLICE_PLAYBOOKS_DIR}${NC}"
echo -e "  Roles: ${YELLOW}${SLICE_ROLES_DIR}${NC}"
echo ""

echo -e "${CYAN}Directory Structure:${NC}"
if command -v tree &> /dev/null; then
    cd "${ANSIBLE_DIR}"
    tree -L 3 -I 'venv|__pycache__|*.pyc' .
else
    echo -e "${YELLOW}(install 'tree' command for better visualization)${NC}"
    echo ""
    echo "Inventory:"
    find "${SLICE_INVENTORY_DIR}" -type f | head -10 | sed 's|'"${ANSIBLE_DIR}"'/|  |'
    echo "Playbooks:"
    find "${SLICE_PLAYBOOKS_DIR}" -type l | head -5 | sed 's|'"${ANSIBLE_DIR}"'/|  |'
    echo "Roles:"
    find "${SLICE_ROLES_DIR}" -type l | head -5 | sed 's|'"${ANSIBLE_DIR}"'/|  |'
fi

echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Review the slice README:"
echo -e "   ${BLUE}cat ${ANSIBLE_DIR}/inventory/${SLICE_NAME}/README.md${NC}"
echo ""
echo "2. Activate virtual environment:"
echo -e "   ${BLUE}cd ${ANSIBLE_DIR}${NC}"
echo -e "   ${BLUE}source venv/bin/activate${NC}"
echo ""
echo "3. Install Galaxy requirements (if needed):"
echo -e "   ${BLUE}./install_requirements.sh${NC}"
echo ""
echo "4. Test connectivity:"
echo -e "   ${BLUE}ansible all_nodes -m ping${NC}"
echo ""
echo "5. Customize variables:"
echo -e "   ${BLUE}vim inventory/${SLICE_NAME}/group_vars/all_nodes.yml${NC}"
echo ""
echo "6. Run base configuration:"
echo -e "   ${BLUE}ansible-playbook playbooks/${SLICE_NAME}/playbook_base_config.yml --check${NC}"
echo -e "   ${BLUE}ansible-playbook playbooks/${SLICE_NAME}/playbook_base_config.yml${NC}"
echo ""

print_success "Ready to use!"
echo ""
