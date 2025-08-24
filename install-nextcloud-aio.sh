#!/bin/bash

# Nextcloud AIO Official Installation Script
# Based strictly on: https://github.com/nextcloud/all-in-one
# Version: 1.0 - IP-based access only, no SSL setup

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Configuration
LOG_FILE="/var/log/nextcloud-aio-install.log"
VPS_IP=""

# Functions
print_header() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${WHITE}                 NEXTCLOUD AIO INSTALLER                     ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${CYAN}              Official Installation - IP Access             ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
}

log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
    log_message "INFO: $1"
}

print_success() {
    echo -e "${GREEN}✅${NC} $1"
    log_message "SUCCESS: $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
    log_message "WARNING: $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
    log_message "ERROR: $1"
}

detect_vps_ip() {
    print_info "Detecting VPS IP address..."
    
    # Try multiple methods to get external IP
    VPS_IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || \
             curl -s --connect-timeout 5 ipinfo.io/ip 2>/dev/null || \
             curl -s --connect-timeout 5 icanhazip.com 2>/dev/null || \
             curl -s --connect-timeout 5 checkip.amazonaws.com 2>/dev/null || \
             echo "")
    
    # Remove any whitespace
    VPS_IP=$(echo "$VPS_IP" | tr -d '[:space:]')
    
    if [[ "$VPS_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        print_success "VPS IP Address detected: $VPS_IP"
    else
        print_warning "Could not detect external IP, trying local interface..."
        VPS_IP=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $7; exit}' || echo "")
        if [[ "$VPS_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            print_success "Local IP detected: $VPS_IP"
        else
            VPS_IP=""
            print_error "Could not detect IP address automatically"
        fi
    fi
}

check_system_requirements() {
    print_info "Checking system requirements..."
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Check OS
    if ! command -v apt &> /dev/null; then
        print_error "This script requires a Debian/Ubuntu system"
        exit 1
    fi
    
    # Check memory
    local mem_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$mem_gb" -lt 2 ]; then
        print_warning "Warning: Only ${mem_gb}GB RAM detected. Nextcloud AIO requires at least 2GB"
    else
        print_success "Memory check passed: ${mem_gb}GB RAM available"
    fi
    
    # Check disk space
    local disk_gb=$(df / | awk 'NR==2{print int($4/1024/1024)}')
    if [ "$disk_gb" -lt 40 ]; then
        print_warning "Warning: Only ${disk_gb}GB free space. Nextcloud AIO requires at least 40GB"
    else
        print_success "Disk space check passed: ${disk_gb}GB available"
    fi
    
    print_success "System requirements check completed"
}

install_docker() {
    print_info "Installing Docker..."
    
    # Update package index
    apt-get update
    
    # Install packages to allow apt to use a repository over HTTPS
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker's official GPG key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up the repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    print_success "Docker installed and started successfully"
}

install_nextcloud_aio() {
    print_info "Installing Nextcloud AIO container..."
    
    # Stop and remove any existing container
    docker stop nextcloud-aio-mastercontainer 2>/dev/null || true
    docker rm nextcloud-aio-mastercontainer 2>/dev/null || true
    
    # Run Nextcloud AIO container - EXACT command from official GitHub
    print_info "Running official Nextcloud AIO container..."
    docker run \
        --init \
        --sig-proxy=false \
        --name nextcloud-aio-mastercontainer \
        --restart always \
        --publish 80:80 \
        --publish 8080:8080 \
        --publish 8443:8443 \
        --publish 3478:3478/tcp \
        --publish 3478:3478/udp \
        --volume nextcloud_aio_mastercontainer:/mnt/docker-aio-config \
        --volume /var/run/docker.sock:/var/run/docker.sock:ro \
        nextcloud/all-in-one:latest
    
    # Wait a moment for container to start
    sleep 5
    
    # Check if container is running
    if docker ps | grep -q "nextcloud-aio-mastercontainer"; then
        print_success "Nextcloud AIO container started successfully"
    else
        print_error "Failed to start Nextcloud AIO container"
        print_info "Checking container logs..."
        docker logs nextcloud-aio-mastercontainer
        exit 1
    fi
}

show_final_info() {
    print_header
    print_success "Nextcloud AIO installation completed successfully!"
    echo
    
    if [ -n "$VPS_IP" ]; then
        echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${WHITE}                    ACCESS INFORMATION                       ${CYAN}║${NC}"
        echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${GREEN}🌐 AIO Admin Panel:${NC}"
        echo -e "${CYAN}║${NC}    ${WHITE}http://$VPS_IP:8080${NC}"
        echo -e "${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${GREEN}🔗 Nextcloud Interface:${NC}"
        echo -e "${CYAN}║${NC}    ${WHITE}http://$VPS_IP:8443${NC} ${YELLOW}(after setup)${NC}"
        echo -e "${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${BLUE}📋 Next Steps:${NC}"
        echo -e "${CYAN}║${NC}    1. Open ${WHITE}http://$VPS_IP:8080${NC} in your browser"
        echo -e "${CYAN}║${NC}    2. Set up backup location (e.g., /mnt/backup)"
        echo -e "${CYAN}║${NC}    3. Select optional containers"
        echo -e "${CYAN}║${NC}    4. Click 'Start containers'"
        echo -e "${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}⚠️  No SSL/Domain setup - IP access only${NC}"
        echo -e "${CYAN}║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    else
        echo -e "${YELLOW}⚠️  Could not detect VPS IP address${NC}"
        echo -e "${CYAN}Please access Nextcloud AIO at: ${WHITE}http://YOUR_VPS_IP:8080${NC}"
    fi
    
    echo
    echo -e "${BLUE}📝 Installation log: ${WHITE}$LOG_FILE${NC}"
    echo
}

# Main installation function
main_install() {
    print_header
    
    # Initialize logging
    mkdir -p "$(dirname "$LOG_FILE")"
    log_message "Nextcloud AIO installation started"
    
    # Run installation steps
    detect_vps_ip
    check_system_requirements
    install_docker
    install_nextcloud_aio
    
    # Show final information
    show_final_info
    
    log_message "Nextcloud AIO installation completed"
}

# Run main installation
main_install
