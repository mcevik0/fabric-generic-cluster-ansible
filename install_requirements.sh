#!/bin/bash
# install_requirements.sh
# Script to install Ansible Galaxy collections

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}Ansible Galaxy Requirements Installer${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""

# Check if requirements.yml exists
if [ ! -f "requirements.yml" ]; then
    echo -e "${RED}Error: requirements.yml not found!${NC}"
    echo "Please ensure requirements.yml is in the current directory."
    exit 1
fi

echo -e "${YELLOW}Installing collections from requirements.yml...${NC}"
echo ""

# Install collections (which includes linux-system-roles)
ansible-galaxy collection install -r requirements.yml --force

echo ""
echo -e "${GREEN}✓ Installation complete!${NC}"
echo ""
echo -e "${BLUE}Installed collections:${NC}"

# Capture full output first to avoid broken pipe
collections_output=$(ansible-galaxy collection list 2>/dev/null)

# Check for specific collections
if echo "$collections_output" | grep -q "community.general"; then
    echo "  ✓ community.general"
fi

if echo "$collections_output" | grep -q "ansible.posix"; then
    echo "  ✓ ansible.posix"
fi

if echo "$collections_output" | grep -q "fedora.linux_system_roles"; then
    echo "  ✓ fedora.linux_system_roles"
fi

echo ""
echo -e "${YELLOW}Verifying linux-system-roles installation:${NC}"

# Better check without broken pipe
if echo "$collections_output" | grep -q "fedora.linux_system_roles"; then
    echo -e "${GREEN}✓ fedora.linux_system_roles collection installed${NC}"
    echo ""
    echo -e "${BLUE}Available system roles:${NC}"
    echo "  - fedora.linux_system_roles.timesync"
    echo "  - fedora.linux_system_roles.selinux"
    echo "  - fedora.linux_system_roles.firewall"
    echo "  - fedora.linux_system_roles.network"
    echo "  - fedora.linux_system_roles.ssh"
    echo "  - fedora.linux_system_roles.logging"
    echo "  - and more..."
else
    echo -e "${RED}✗ fedora.linux_system_roles collection NOT found${NC}"
    echo "Try running: ansible-galaxy collection install fedora.linux_system_roles"
fi

echo ""
echo -e "${YELLOW}Collection install location:${NC}"
echo "  ~/.ansible/collections/ansible_collections/"
echo ""
echo -e "${GREEN}Ready to use!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Test configuration: ansible-playbook playbooks/default/playbook_base_config.yml --check"
echo "  2. Run on test host: ansible-playbook playbooks/default/playbook_base_config.yml -l lc-10"
echo "  3. Read documentation: cat ROLES_README.md"
echo ""
