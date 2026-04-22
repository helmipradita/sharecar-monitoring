#!/bin/bash

#=============================================================================
# Docker Native Linux Installation Script for Amazon Linux 2023
# Version: 1.0
# Description: Uninstall Docker Desktop & Install Docker Engine Native
# Docker Engine Version: 27.x (Stable as of 2026)
#=============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Symbols
CHECK_MARK="${GREEN}✓${NC}"
CROSS_MARK="${RED}✗${NC}"
ARROW="${CYAN}➜${NC}"
ROCKET="${PURPLE}🚀${NC}"
WARNING="${YELLOW}⚠${NC}"

# Banner
print_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║        Docker Native Linux Installer for Amazon Linux 2023        ║"
    echo "║                  Version: 27.x (Stable - 2026)                      ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Print section header
print_section() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# Print success
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Print error
print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Print info
print_info() {
    echo -e "${CYAN}➜${NC} $1"
}

# Print warning
print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

#=============================================================================
# STEP 1: SYSTEM CHECK
#=============================================================================
check_system() {
    print_section "STEP 1: SYSTEM CHECK"

    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        print_error "Please do not run this script as root directly."
        print_info "Use: sudo $0"
        exit 1
    fi

    # Check OS
    if [[ ! -f /etc/system-release ]]; then
        print_error "Cannot determine OS version"
        exit 1
    fi

    OS_INFO=$(cat /etc/system-release)
    print_success "OS Detected: $OS_INFO"

    # Check if Amazon Linux 2023 (various version formats)
    if ! echo "$OS_INFO" | grep -qE "Amazon Linux.*2023"; then
        print_warning "This script is designed for Amazon Linux 2023"
        print_info "Your OS: $OS_INFO"
        read -p "Continue anyway? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_success "Amazon Linux 2023 detected - proceeding with installation"
    fi

    # Check current Docker installation
    print_info "Checking current Docker installation..."
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version 2>/dev/null || echo "unknown")
        print_info "Current Docker: $DOCKER_VERSION"

        # Check if Docker Desktop
        if docker --version 2>/dev/null | grep -q "Docker Desktop"; then
            print_warning "Docker Desktop detected!"
            print_warning "This version will be replaced with Docker Engine Native"
        fi
    else
        print_info "No Docker installation found"
    fi
}

#=============================================================================
# STEP 2: STOP RUNNING CONTAINERS
#=============================================================================
stop_containers() {
    print_section "STEP 2: STOPPING CONTAINERS"

    print_info "Stopping all running containers..."
    RUNNING_CONTAINERS=$(docker ps -q 2>/dev/null || true)

    if [[ -n "$RUNNING_CONTAINERS" ]]; then
        docker stop $RUNNING_CONTAINERS 2>/dev/null || true
        print_success "Stopped $(echo $RUNNING_CONTAINERS | wc -w) containers"
    else
        print_info "No running containers found"
    fi
}

#=============================================================================
# STEP 3: UNINSTALL DOCKER DESKTOP
#=============================================================================
uninstall_docker_desktop() {
    print_section "STEP 3: UNINSTALLING DOCKER DESKTOP"

    print_info "Removing Docker Desktop service files..."
    sudo systemctl --user stop docker-desktop 2>/dev/null || true
    sudo systemctl disable docker-desktop.service 2>/dev/null || true
    sudo systemctl disable docker-desktop.socket 2>/dev/null || true

    print_info "Removing Docker Desktop files..."
    sudo rm -rf /usr/share/docker-desktop 2>/dev/null || true
    sudo rm -rf /usr/bin/docker-desktop 2>/dev/null || true
    sudo rm -rf $HOME/.docker/desktop 2>/dev/null || true
    sudo rm -rf /usr/share/applications/docker-desktop.desktop 2>/dev/null || true
    sudo rm -rf /var/lib/docker-desktop 2>/dev/null || true

    print_info "Removing systemd units..."
    sudo rm -f /etc/systemd/system/docker-desktop.service 2>/dev/null || true
    sudo rm -f /etc/systemd/system/docker-desktop.socket 2>/dev/null || true
    sudo rm -f /etc/systemd/user/docker-desktop.service 2>/dev/null || true
    sudo rm -f /etc/systemd/user/docker-desktop.socket 2>/dev/null || true
    sudo systemctl daemon-reload

    print_success "Docker Desktop uninstalled"
}

#=============================================================================
# STEP 4: REMOVE OLD DOCKER PACKAGES
#=============================================================================
remove_old_packages() {
    print_section "STEP 4: REMOVING OLD DOCKER PACKAGES"

    print_info "Removing old Docker packages..."
    sudo dnf remove -y docker docker-client docker-client-latest docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null || true

    print_info "Cleaning up残留 files..."
    sudo rm -rf /var/lib/docker 2>/dev/null || true
    sudo rm -rf /var/lib/containerd 2>/dev/null || true

    print_success "Old packages removed"
}

#=============================================================================
# STEP 5: INSTALL DEPENDENCIES
#=============================================================================
install_dependencies() {
    print_section "STEP 5: INSTALLING DEPENDENCIES"

    print_info "Updating system..."
    sudo dnf update -y -q

    print_info "Checking required packages..."
    # Amazon Linux 2023 already has curl-minimal and gnupg2-minimal
    # Just check if curl and gpg commands are available
    if command -v curl &> /dev/null; then
        print_success "curl is available"
    else
        print_info "Installing curl..."
        sudo dnf install -y -q curl-minimal
    fi

    if command -v gpg &> /dev/null; then
        print_success "gpg is available"
    else
        print_info "Installing gnupg2..."
        sudo dnf install -y -q gnupg2-minimal
    fi

    print_success "Dependencies checked"
}

#=============================================================================
# STEP 6: ADD DOCKER REPOSITORY
#=============================================================================
add_docker_repo() {
    print_section "STEP 6: CONFIGURING DOCKER REPOSITORY"

    print_info "Adding Docker official GPG key..."
    sudo rpm --import https://download.docker.com/linux/centos/gpg 2>/dev/null || true

    print_info "Adding Docker repository..."
    sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

    print_success "Docker repository configured"
}

#=============================================================================
# STEP 7: INSTALL DOCKER ENGINE
#=============================================================================
install_docker_engine() {
    print_section "STEP 7: INSTALLING DOCKER ENGINE"

    print_info "Installing Docker Engine 27.x (Latest Stable)..."
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    print_success "Docker Engine installed"
}

#=============================================================================
# STEP 8: ENABLE AND START DOCKER
#=============================================================================
start_docker() {
    print_section "STEP 8: STARTING DOCKER SERVICE"

    print_info "Enabling Docker service..."
    sudo systemctl enable docker

    print_info "Starting Docker service..."
    sudo systemctl start docker

    print_success "Docker service started"
}

#=============================================================================
# STEP 9: CONFIGURE USER PERMISSIONS
#=============================================================================
configure_user() {
    print_section "STEP 9: CONFIGURING USER PERMISSIONS"

    print_info "Adding current user to docker group..."
    sudo usermod -aG docker $USER

    print_warning "You need to log out and log back in for group changes to take effect"
    print_info "Or run: newgrp docker"
}

#=============================================================================
# STEP 10: VERIFY INSTALLATION
#=============================================================================
verify_installation() {
    print_section "STEP 10: VERIFICATION"

    # Docker version
    if command -v docker &> /dev/null; then
        DOVER=$(docker --version)
        echo -e "  ${GREEN}✓${NC} ${DOVER}"
    else
        echo -e "  ${RED}✗${NC} Docker command not found"
        return 1
    fi

    # Docker Compose version
    if docker compose version &> /dev/null; then
        DCVER=$(docker compose version)
        echo -e "  ${GREEN}✓${NC} ${DCVER}"
    else
        echo -e "  ${RED}✗${NC} Docker Compose not found"
        return 1
    fi

    # Docker info
    if docker info &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} Docker daemon is running"
    else
        echo -e "  ${RED}✗${NC} Docker daemon not accessible"
        return 1
    fi

    # Test run
    print_info "Running test container..."
    if docker run --rm hello-world &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} Docker can run containers successfully"
    else
        echo -e "  ${RED}✗${NC} Docker test failed"
        return 1
    fi

    print_success "All verifications passed!"
}

#=============================================================================
# STEP 11: POST-INSTALLATION SUMMARY
#=============================================================================
print_summary() {
    print_section "INSTALLATION COMPLETE"

    echo -e "${GREEN}"
    echo "  ███████╗██╗   ██╗███████╗██████╗  ██████╗ ███████╗"
    echo "  ██╔════╝██║   ██║██╔════╝██╔══██╗██╔═══██╗██╔════╝"
    echo "  ███████╗██║   ██║█████╗  ██████╔╝██║   ██║███████╗"
    echo "  ╚════██║██║   ██║██╔══╝  ██╔══██╗██║   ██║╚════██║"
    echo "  ███████║╚██████╔╝███████╗██████╔╝╚██████╔╝███████║"
    echo "  ╚══════╝ ╚═════╝ ╚══════╝╚═════╝  ╚═════╝ ╚══════╝"
    echo -e "${NC}"

    echo -e "\n${CYAN}  Docker Engine Native Linux has been installed successfully!${NC}\n"

    echo -e "  ${YELLOW}IMPORTANT NOTES:${NC}"
    echo -e "    ${YELLOW}•${NC} Log out and log back in OR run: ${GREEN}newgrp docker${NC}"
    echo -e "    ${YELLOW}•${NC} Docker Compose v2 is now built-in: ${GREEN}docker compose${NC}"
    echo -e "    ${YELLOW}•${NC} No more 'docker-compose' (v1) needed\n"

    echo -e "  ${CYAN}QUICK COMMANDS:${NC}"
    echo -e "    docker ps              ${GRAY}# List containers${NC}"
    echo -e "    docker compose up -d  ${GRAY}# Start services${NC}"
    echo -e "    docker compose down   ${GRAY}# Stop services${NC}\n"

    echo -e "  ${CYAN}NEXT STEPS:${NC}"
    echo -e "    1. Log out and log back in"
    echo -e "    2. Navigate to your project: ${GREEN}cd /path/to/sharecar-monitoring${NC}"
    echo -e "    3. Start monitoring stack: ${GREEN}docker compose --profile full up -d${NC}\n"
}

#=============================================================================
# MAIN EXECUTION
#=============================================================================
main() {
    print_banner

    # Check if user wants to proceed
    if [[ "$1" != "--yes" ]]; then
        echo -e "${YELLOW}This script will:${NC}"
        echo "  • Stop all running Docker containers"
        echo "  • Uninstall Docker Desktop"
        echo "  • Remove old Docker packages"
        echo "  • Install Docker Engine Native Linux"
        echo ""
        read -p "Continue? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Installation cancelled"
            exit 0
        fi
    fi

    check_system
    stop_containers
    uninstall_docker_desktop
    remove_old_packages
    install_dependencies
    add_docker_repo
    install_docker_engine
    start_docker
    configure_user
    verify_installation
    print_summary
}

# Run main
main "$@"
