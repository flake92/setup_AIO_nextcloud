#!/bin/bash

# 🌟 Nextcloud AIO - Универсальный установщик
# Полностью автоматизированная установка с защитой от отключения SSH
# Поддерживает любые Linux дистрибутивы через Docker

set -euo pipefail

# 🎨 Цвета и стили
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m'

# 🔧 Конфигурация
INSTALL_LOG="/var/log/nextcloud-aio-install.log"
SCREEN_SESSION="nextcloud-aio-install"
CONTAINER_NAME="nextcloud-aio"
PID_FILE="/var/run/nextcloud-aio-install.pid"
VPS_IP=""

# 🎨 Красивые символы
CHECKMARK="✅"
CROSS="❌"
WARNING="⚠️"
INFO="ℹ️"
ROCKET="🚀"
GEAR="⚙️"
CLOUD="☁️"

# ═══════════════════════════════════════════════════════════════════════════════
# 🎨 КРАСИВЫЕ ФУНКЦИИ ИНТЕРФЕЙСА
# ═══════════════════════════════════════════════════════════════════════════════

print_banner() {
    clear
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                          ║"
    echo "║    ${CLOUD}${WHITE}  NEXTCLOUD AIO - АВТОМАТИЧЕСКАЯ УСТАНОВКА  ${CLOUD}${PURPLE}                ║"
    echo "║                                                                          ║"
    echo "║    ${CYAN}Красивое интерактивное меню с защитой от отключения SSH${PURPLE}        ║"
    echo "║                                                                          ║"
    echo "╚══════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"
}

print_status_box() {
    local container_status
    local install_status
    local progress
    container_status=$(get_container_status)
    install_status=$(get_install_status)
    progress=$(get_install_progress)
    
    echo -e "${CYAN}"
    echo "┌─────────────────────────── ${WHITE}СТАТУС СИСТЕМЫ${CYAN} ───────────────────────────┐"
    
    # Статус установки
    case $install_status in
        "running")
            echo -e "│ ${GEAR}${YELLOW} Установка:${NC} ${BLUE}Выполняется${NC} ${GRAY}($progress)${NC}                           ${CYAN}│"
            ;;
        "completed")
            echo -e "│ ${CHECKMARK}${GREEN} Установка:${NC} ${GREEN}Завершена успешно${NC}                              ${CYAN}│"
            ;;
        "failed")
            echo -e "│ ${CROSS}${RED} Установка:${NC} ${RED}Ошибка${NC}                                        ${CYAN}│"
            ;;
        *)
            echo -e "│ ${INFO}${GRAY} Установка:${NC} ${GRAY}Не запущена${NC}                                   ${CYAN}│"
            ;;
    esac
    
    # Статус контейнера
    case $container_status in
        "running")
            echo -e "│ ${CHECKMARK}${GREEN} Контейнер:${NC} ${GREEN}Активен и работает${NC}                            ${CYAN}│"
            ;;
        "stopped")
            echo -e "│ ${WARNING}${YELLOW} Контейнер:${NC} ${YELLOW}Остановлен${NC}                                    ${CYAN}│"
            ;;
        *)
            echo -e "│ ${CROSS}${RED} Контейнер:${NC} ${RED}Не найден${NC}                                      ${CYAN}│"
            ;;
    esac
    
    # IP адрес
    if [ -n "$VPS_IP" ]; then
        echo -e "│ ${CLOUD}${BLUE} IP адрес:${NC} ${WHITE}$VPS_IP${NC}                                        ${CYAN}│"
    else
        echo -e "│ ${WARNING}${YELLOW} IP адрес:${NC} ${GRAY}Определяется...${NC}                                ${CYAN}│"
    fi
    
    echo -e "└──────────────────────────────────────────────────────────────────────┘${NC}\n"
}

print_menu() {
    echo -e "${WHITE}"
    echo "┌─────────────────────────── ${CYAN}ГЛАВНОЕ МЕНЮ${WHITE} ────────────────────────────┐"
    
    local install_status
    local container_status
    install_status=$(get_install_status)
    container_status=$(get_container_status)
    
    # Динамическое меню в зависимости от статуса
    if [ "$install_status" = "not_started" ] || [ "$install_status" = "failed" ]; then
        echo -e "│  ${ROCKET}${GREEN} 1${NC} ${GREEN}Запустить автоматическую установку${NC}                       ${WHITE}│"
        echo -e "│  ${INFO}${BLUE} 2${NC} ${BLUE}Диагностика системы${NC}                                      ${WHITE}│"
        echo -e "│                                                                      ${WHITE}│"
        
    elif [ "$install_status" = "running" ]; then
        echo -e "│  ${GEAR}${BLUE} 1${NC} ${BLUE}Подключиться к процессу установки${NC}                        ${WHITE}│"
        echo -e "│  ${INFO}${YELLOW} 2${NC} ${YELLOW}Показать логи установки${NC}                                  ${WHITE}│"
        echo -e "│  ${CROSS}${RED} 3${NC} ${RED}Перезапустить установку${NC}                                  ${WHITE}│"
        echo -e "│                                                                      ${WHITE}│"
        
    elif [ "$install_status" = "completed" ]; then
        if [ "$container_status" = "running" ]; then
            echo -e "│  ${CHECKMARK}${GREEN} 1${NC} ${GREEN}Управление контейнером${NC}                                   ${WHITE}│"
            echo -e "│  ${INFO}${BLUE} 2${NC} ${BLUE}Показать информацию о доступе${NC}                             ${WHITE}│"
            echo -e "│  ${GEAR}${YELLOW} 3${NC} ${YELLOW}Диагностика системы${NC}                                      ${WHITE}│"
            echo -e "│  ${ROCKET}${PURPLE} 4${NC} ${PURPLE}Переустановить Nextcloud AIO${NC}                             ${WHITE}│"
        else
            echo -e "│  ${ROCKET}${GREEN} 1${NC} ${GREEN}Запустить контейнер${NC}                                      ${WHITE}│"
            echo -e "│  ${INFO}${BLUE} 2${NC} ${BLUE}Показать информацию о доступе${NC}                             ${WHITE}│"
            echo -e "│  ${GEAR}${YELLOW} 3${NC} ${YELLOW}Диагностика системы${NC}                                      ${WHITE}│"
            echo -e "│  ${ROCKET}${PURPLE} 4${NC} ${PURPLE}Переустановить Nextcloud AIO${NC}                             ${WHITE}│"
        fi
        echo -e "│                                                                      ${WHITE}│"
    fi
    
    echo -e "│  ${GRAY} 0${NC} ${GRAY}Выход${NC}                                                        ${WHITE}│"
    echo -e "└──────────────────────────────────────────────────────────────────────┘${NC}\n"
    echo -e "${CYAN}Выберите опцию:${NC} "
}

# ═══════════════════════════════════════════════════════════════════════════════
# 🔧 СИСТЕМНЫЕ ФУНКЦИИ
# ═══════════════════════════════════════════════════════════════════════════════

check_root() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # На macOS не требуем root для разработки/тестирования
        if [ "$EUID" -eq 0 ]; then
            echo -e "${YELLOW}${WARNING} Запуск от root на macOS не рекомендуется${NC}"
        fi
        return 0
    fi
    
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}${CROSS} Требуются права root. Перезапуск с sudo...${NC}"
        exec sudo "$0"
    fi
}

detect_os() {
    # Определяем операционную систему
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        OS_ID="macos"
        OS_VERSION=$(sw_vers -productVersion)
        OS_NAME="macOS $OS_VERSION"
        PACKAGE_MANAGER="brew"
    elif [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID="$ID"
        OS_VERSION="$VERSION_ID"
        export OS_CODENAME="$VERSION_CODENAME"
        OS_NAME="$PRETTY_NAME"
    elif [ -f /etc/debian_version ]; then
        OS_ID="debian"
        OS_VERSION=$(cat /etc/debian_version | cut -d. -f1)
        OS_NAME="Debian $OS_VERSION"
    elif [ -f /etc/redhat-release ]; then
        OS_ID="rhel"
        OS_NAME=$(cat /etc/redhat-release)
    elif [ -f /etc/arch-release ]; then
        export OS_ID="arch"
        OS_NAME="Arch Linux"
    else
        echo -e "${RED}${CROSS} Неподдерживаемая операционная система${NC}"
        exit 1
    fi
    
    # Устанавливаем пакетный менеджер для Linux систем
    if [[ "$OSTYPE" != "darwin"* ]]; then
        if command -v apt-get &> /dev/null; then
            PACKAGE_MANAGER="apt"
        elif command -v dnf &> /dev/null; then
            PACKAGE_MANAGER="dnf"
        elif command -v yum &> /dev/null; then
            PACKAGE_MANAGER="yum"
        elif command -v pacman &> /dev/null; then
            PACKAGE_MANAGER="pacman"
        elif command -v zypper &> /dev/null; then
            PACKAGE_MANAGER="zypper"
        else
            echo -e "${RED}${CROSS} Неподдерживаемый пакетный менеджер${NC}"
            exit 1
        fi
    fi
    
    echo -e "${BLUE}${INFO} Обнаружена система: $OS_NAME${NC}"
    
    # Проверяем наличие Docker
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}${CHECKMARK} Docker уже установлен${NC}"
        DOCKER_INSTALLED=true
    else
        echo -e "${YELLOW}${WARNING} Docker не найден, будет установлен${NC}"
        DOCKER_INSTALLED=false
    fi
}

install_docker_universal() {
    if [ "$DOCKER_INSTALLED" = true ]; then
        return 0
    fi
    
    echo -e "${BLUE}${GEAR} Установка Docker универсальным способом...${NC}"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - Docker Desktop
        echo -e "${BLUE}${INFO} На macOS требуется Docker Desktop${NC}"
        echo -e "${YELLOW}${WARNING} Установите Docker Desktop вручную:${NC}"
        echo -e "${CYAN}1. Скачайте с https://www.docker.com/products/docker-desktop${NC}"
        echo -e "${CYAN}2. Установите и запустите Docker Desktop${NC}"
        echo -e "${CYAN}3. Перезапустите этот скрипт${NC}"
        
        # Проверяем наличие Homebrew для альтернативной установки
        if command -v brew &> /dev/null; then
            echo -e "${BLUE}${INFO} Альтернативно, можете установить через Homebrew:${NC}"
            echo -e "${CYAN}brew install --cask docker${NC}"
        fi
        
        exit 1
    else
        # Linux - используем официальный скрипт Docker
        if curl -fsSL https://get.docker.com | sh; then
            echo -e "${GREEN}${CHECKMARK} Docker успешно установлен${NC}"
            
            # Запускаем и включаем Docker
            if systemctl start docker && systemctl enable docker; then
                echo -e "${GREEN}${CHECKMARK} Docker запущен и настроен${NC}"
            else
                echo -e "${YELLOW}${WARNING} Не удалось настроить автозапуск Docker${NC}"
            fi
            
            # Проверяем работу Docker
            if docker --version &>/dev/null; then
                echo -e "${GREEN}${CHECKMARK} Docker работает корректно${NC}"
                return 0
            else
                echo -e "${RED}${CROSS} Docker установлен, но не работает${NC}"
                return 1
            fi
        else
            echo -e "${RED}${CROSS} Ошибка установки Docker${NC}"
            return 1
        fi
    fi
}

update_system() {
    echo -e "${BLUE}${GEAR} Обновление системы...${NC}"
    
    case "$PACKAGE_MANAGER" in
        apt)
            # Debian/Ubuntu
            if ! apt-get update -qq; then
                echo -e "${RED}${CROSS} Ошибка обновления списка пакетов${NC}"
                exit 1
            fi
            
            local base_packages="curl wget gnupg lsb-release ca-certificates apt-transport-https software-properties-common"
            local missing_packages=""
            
            for package in $base_packages; do
                if ! dpkg -l | grep -q "^ii  $package "; then
                    missing_packages="$missing_packages $package"
                fi
            done
            
            if [ -n "$missing_packages" ]; then
                echo -e "${BLUE}${GEAR} Установка базовых пакетов:$missing_packages${NC}"
                if ! apt-get install -y "$missing_packages" &>/dev/null; then
                    echo -e "${RED}${CROSS} Ошибка установки базовых пакетов${NC}"
                    exit 1
                fi
            fi
            ;;
            
        dnf|yum)
            # RHEL/CentOS/Fedora
            if ! $PACKAGE_MANAGER update -y -q; then
                echo -e "${RED}${CROSS} Ошибка обновления списка пакетов${NC}"
                exit 1
            fi
            
            local base_packages="curl wget gnupg2 ca-certificates"
            echo -e "${BLUE}${GEAR} Установка базовых пакетов: $base_packages${NC}"
            if ! $PACKAGE_MANAGER install -y "$base_packages" &>/dev/null; then
                echo -e "${RED}${CROSS} Ошибка установки базовых пакетов${NC}"
                exit 1
            fi
            ;;
            
        pacman)
            # Arch Linux
            if ! pacman -Sy --noconfirm; then
                echo -e "${RED}${CROSS} Ошибка обновления списка пакетов${NC}"
                exit 1
            fi
            
            local base_packages="curl wget gnupg ca-certificates"
            echo -e "${BLUE}${GEAR} Установка базовых пакетов: $base_packages${NC}"
            if ! pacman -S --noconfirm "$base_packages" &>/dev/null; then
                echo -e "${RED}${CROSS} Ошибка установки базовых пакетов${NC}"
                exit 1
            fi
            ;;
            
        zypper)
            # openSUSE
            if ! zypper refresh -q; then
                echo -e "${RED}${CROSS} Ошибка обновления списка пакетов${NC}"
                exit 1
            fi
            
            local base_packages="curl wget gpg2 ca-certificates"
            echo -e "${BLUE}${GEAR} Установка базовых пакетов: $base_packages${NC}"
            if ! zypper install -y "$base_packages" &>/dev/null; then
                echo -e "${RED}${CROSS} Ошибка установки базовых пакетов${NC}"
                exit 1
            fi
            ;;
            
        brew)
            # macOS - Homebrew
            if ! command -v brew &> /dev/null; then
                echo -e "${YELLOW}${WARNING} Homebrew не найден, устанавливаем...${NC}"
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                
                # Добавляем Homebrew в PATH для Apple Silicon
                if [[ $(uname -m) == "arm64" ]]; then
                    echo "export PATH=\"/opt/homebrew/bin:\$PATH\"" >> ~/.zshrc
                    export PATH="/opt/homebrew/bin:$PATH"
                else
                    echo "export PATH=\"/usr/local/bin:\$PATH\"" >> ~/.zshrc
                    export PATH="/usr/local/bin:$PATH"
                fi
            fi
            
            echo -e "${BLUE}${GEAR} Обновление Homebrew...${NC}"
            if ! brew update &>/dev/null; then
                echo -e "${YELLOW}${WARNING} Не удалось обновить Homebrew${NC}"
            fi
            
            local base_packages="curl wget gnupg screen"
            echo -e "${BLUE}${GEAR} Установка базовых пакетов: $base_packages${NC}"
            for package in $base_packages; do
                if ! brew list "$package" &>/dev/null; then
                    if ! brew install "$package" &>/dev/null; then
                        echo -e "${YELLOW}${WARNING} Не удалось установить $package${NC}"
                    fi
                fi
            done
            ;;
    esac
    
    echo -e "${GREEN}${CHECKMARK} Система обновлена и готова${NC}"
}

detect_ip() {
    if [ -z "$VPS_IP" ]; then
        VPS_IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || echo "")
        VPS_IP=$(echo "$VPS_IP" | tr -d '[:space:]')
    fi
}

install_dependencies() {
    echo -e "${BLUE}${GEAR} Проверка и установка зависимостей...${NC}"
    
    # Список необходимых пакетов
    local required_packages="screen curl wget gnupg lsb-release ca-certificates apt-transport-https"
    local missing_packages=""
    
    # Проверяем какие пакеты отсутствуют
    for package in $required_packages; do
        if ! command -v "$package" &> /dev/null && ! dpkg -l | grep -q "^ii  $package "; then
            missing_packages="$missing_packages $package"
        fi
    done
    
    # Устанавливаем отсутствующие пакеты
    if [ -n "$missing_packages" ]; then
        echo -e "${BLUE}${GEAR} Установка недостающих пакетов:$missing_packages${NC}"
        if ! apt-get install -y "$missing_packages" &>/dev/null; then
            echo -e "${RED}${CROSS} Ошибка установки зависимостей${NC}"
            exit 1
        fi
        echo -e "${GREEN}${CHECKMARK} Зависимости установлены${NC}"
    else
        echo -e "${GREEN}${CHECKMARK} Все зависимости уже установлены${NC}"
    fi
}

get_container_status() {
    if docker ps | grep -q "$CONTAINER_NAME"; then
        echo "running"
    elif docker ps -a | grep -q "$CONTAINER_NAME"; then
        echo "stopped"
    else
        echo "not_found"
    fi
}

get_install_status() {
    if screen -list | grep -q "$SCREEN_SESSION"; then
        echo "running"
    elif [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "running"
        else
            rm -f "$PID_FILE"
            if [ -f "$INSTALL_LOG" ] && grep -q "installation completed successfully" "$INSTALL_LOG"; then
                echo "completed"
            elif [ -f "$INSTALL_LOG" ] && grep -q "ERROR\|FAILED" "$INSTALL_LOG"; then
                echo "failed"
            else
                echo "not_started"
            fi
        fi
    elif [ -f "$INSTALL_LOG" ] && grep -q "installation completed successfully" "$INSTALL_LOG"; then
        echo "completed"
    elif [ -f "$INSTALL_LOG" ] && grep -q "ERROR\|FAILED" "$INSTALL_LOG"; then
        echo "failed"
    else
        echo "not_started"
    fi
}

get_install_progress() {
    if [ ! -f "$INSTALL_LOG" ]; then
        echo "0/8"
        return
    fi
    
    local completed=0
    grep -q "Проверка системы" "$INSTALL_LOG" && ((completed++))
    grep -q "Обновление системы" "$INSTALL_LOG" && ((completed++))
    grep -q "Определение IP" "$INSTALL_LOG" && ((completed++))
    grep -q "Проверка требований" "$INSTALL_LOG" && ((completed++))
    grep -q "Установка Docker" "$INSTALL_LOG" && ((completed++))
    grep -q "Настройка Docker" "$INSTALL_LOG" && ((completed++))
    grep -q "Запуск Nextcloud" "$INSTALL_LOG" && ((completed++))
    grep -q "installation completed successfully" "$INSTALL_LOG" && ((completed++))
    
    echo "$completed/8"
}

# ═══════════════════════════════════════════════════════════════════════════════
# 🚀 ОСНОВНЫЕ ФУНКЦИИ
# ═══════════════════════════════════════════════════════════════════════════════

start_installation() {
    local install_status
    install_status=$(get_install_status)
    
    if [ "$install_status" = "running" ]; then
        echo -e "${YELLOW}${WARNING} Установка уже выполняется${NC}"
        echo -n "Подключиться к процессу? (y/N): "
        read -r confirm
        if [[ $confirm =~ ^[Yy]$ ]]; then
            connect_to_installation
        fi
        return
    fi
    
    print_banner
    echo -e "${GREEN}"
    echo "┌─────────────────────── ${WHITE}АВТОМАТИЧЕСКАЯ УСТАНОВКА${GREEN} ──────────────────────┐"
    echo -e "│  ${ROCKET} Nextcloud AIO будет установлен автоматически                   ${GREEN}│"
    echo -e "│  🔒 Установка защищена от отключения SSH через screen            ${GREEN}│"
    echo -e "│  📊 Вы можете отключиться и подключиться в любой момент           ${GREEN}│"
    echo -e "└──────────────────────────────────────────────────────────────────────┘${NC}\n"
    
    echo -e "${YELLOW}Начать установку? (Y/n):${NC} "
    read -r confirm
    
    if [[ ! $confirm =~ ^[Nn]$ ]]; then
        true > "$INSTALL_LOG"
        echo -e "${BLUE}${GEAR} Запуск защищенной установки...${NC}"
        
        # Создаем полностью автоматизированную screen-сессию
        screen -dmS "$SCREEN_SESSION" bash -c "
            echo \$\$ > '$PID_FILE'
            
            log_step() {
                echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] \$1\" | tee -a '$INSTALL_LOG'
            }
            
            log_error() {
                echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] ERROR: \$1\" | tee -a '$INSTALL_LOG'
            }
            
            log_step 'Начало автоматической установки Nextcloud AIO'
            
            # Проверка системы
            log_step 'Определение операционной системы...'
            
            # Определяем ОС
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                OS_ID=\"\$ID\"
                OS_NAME=\"\$PRETTY_NAME\"
                log_step \"Обнаружена система: \$OS_NAME\"
            else
                log_error 'Не удалось определить операционную систему'
                exit 1
            fi
            
            # Определяем пакетный менеджер
            case \"\$OS_ID\" in
                debian|ubuntu)
                    PACKAGE_MANAGER=\"apt\"
                    ;;
                fedora|centos|rhel|rocky|almalinux)
                    PACKAGE_MANAGER=\"dnf\"
                    if ! command -v dnf &> /dev/null; then
                        PACKAGE_MANAGER=\"yum\"
                    fi
                    ;;
                arch|manjaro)
                    PACKAGE_MANAGER=\"pacman\"
                    ;;
                opensuse*|sles)
                    PACKAGE_MANAGER=\"zypper\"
                    ;;
                *)
                    PACKAGE_MANAGER=\"apt\"
                    ;;
            esac
            
            log_step \"Используется пакетный менеджер: \$PACKAGE_MANAGER\"
            
            # Обновление системы
            log_step 'Обновление системы и установка базовых пакетов...'
            
            case \"\$PACKAGE_MANAGER\" in
                apt)
                    export DEBIAN_FRONTEND=noninteractive
                    if ! apt-get update -qq; then
                        log_error 'Ошибка обновления списка пакетов'
                        exit 1
                    fi
                    
                    base_packages=\"curl wget gnupg lsb-release ca-certificates apt-transport-https software-properties-common\"
                    if ! apt-get install -y \$base_packages &>/dev/null; then
                        log_error 'Ошибка установки базовых пакетов'
                        exit 1
                    fi
                    ;;
                dnf|yum)
                    if ! \$PACKAGE_MANAGER update -y -q; then
                        log_error 'Ошибка обновления списка пакетов'
                        exit 1
                    fi
                    
                    base_packages=\"curl wget gnupg2 ca-certificates\"
                    if ! \$PACKAGE_MANAGER install -y \$base_packages &>/dev/null; then
                        log_error 'Ошибка установки базовых пакетов'
                        exit 1
                    fi
                    ;;
                pacman)
                    if ! pacman -Sy --noconfirm; then
                        log_error 'Ошибка обновления списка пакетов'
                        exit 1
                    fi
                    
                    base_packages=\"curl wget gnupg ca-certificates\"
                    if ! pacman -S --noconfirm \$base_packages &>/dev/null; then
                        log_error 'Ошибка установки базовых пакетов'
                        exit 1
                    fi
                    ;;
                zypper)
                    if ! zypper refresh -q; then
                        log_error 'Ошибка обновления списка пакетов'
                        exit 1
                    fi
                    
                    base_packages=\"curl wget gpg2 ca-certificates\"
                    if ! zypper install -y \$base_packages &>/dev/null; then
                        log_error 'Ошибка установки базовых пакетов'
                        exit 1
                    fi
                    ;;
            esac
            
            log_step 'Определение IP адреса VPS...'
            VPS_IP=\$(curl -s --connect-timeout 10 ifconfig.me 2>/dev/null || \\
                     curl -s --connect-timeout 10 ipinfo.io/ip 2>/dev/null || \\
                     curl -s --connect-timeout 10 icanhazip.com 2>/dev/null || \\
                     echo '')
            
            if [ -n \"\$VPS_IP\" ]; then
                log_step \"IP адрес определен: \$VPS_IP\"
            else
                log_step 'WARNING: Не удалось определить внешний IP адрес'
            fi
            
            # Проверка системных требований
            log_step 'Проверка системных требований...'
            
            # Память
            mem_gb=\$(free -g | awk '/^Mem:/{print \$2}')
            if [ \"\$mem_gb\" -lt 2 ]; then
                log_step \"WARNING: Всего \${mem_gb}GB RAM. Рекомендуется минимум 2GB\"
            else
                log_step \"Память: \${mem_gb}GB RAM - OK\"
            fi
            
            # Диск
            disk_gb=\$(df / | awk 'NR==2{print int(\$4/1024/1024)}')
            if [ \"\$disk_gb\" -lt 40 ]; then
                log_step \"WARNING: Свободно \${disk_gb}GB. Рекомендуется минимум 40GB\"
            else
                log_step \"Диск: \${disk_gb}GB свободно - OK\"
            fi
            
            # Установка Docker универсальным способом
            log_step 'Установка Docker...'
            
            # Проверяем наличие Docker
            if command -v docker &> /dev/null; then
                log_step 'Docker уже установлен, пропускаем установку'
            else
                # Используем официальный скрипт Docker - работает на всех дистрибутивах
                log_step 'Загрузка и запуск официального установщика Docker...'
                if ! curl -fsSL https://get.docker.com | sh; then
                    log_error 'Ошибка установки Docker через официальный скрипт'
                    exit 1
                fi
                
                log_step 'Docker успешно установлен'
            fi
            
            log_step 'Настройка Docker...'
            
            # Останавливаем старый контейнер если есть
            docker stop '$CONTAINER_NAME' 2>/dev/null || true
            docker rm '$CONTAINER_NAME' 2>/dev/null || true
            
            # Скачиваем образ заранее
            if ! docker pull nextcloud/all-in-one:latest &>/dev/null; then
                log_error 'Ошибка загрузки образа Nextcloud AIO'
                exit 1
{{ ... }}
            fi
            
            # Запускаем контейнер для прямого доступа по IP (без SSL/reverse proxy)
            if ! docker run \\
                --init \\
                --sig-proxy=false \\
                --name '$CONTAINER_NAME' \\
                --restart always \\
                --publish 8080:8080 \\
                --publish 8443:8443 \\
                --publish 3478:3478/tcp \\
                --publish 3478:3478/udp \\
                --volume nextcloud_aio_mastercontainer:/mnt/docker-aio-config \\
                --volume /var/run/docker.sock:/var/run/docker.sock:ro \\
                --env SKIP_DOMAIN_VALIDATION=true \\
                nextcloud/all-in-one:latest &>/dev/null & then
                log_error 'Ошибка запуска контейнера Nextcloud AIO'
                exit 1
            fi
            
            # Ждем запуска контейнера
            log_step 'Ожидание запуска контейнера...'
            sleep 15
            
            # Проверяем статус контейнера
            if docker ps | grep -q '$CONTAINER_NAME'; then
                log_step 'Nextcloud AIO контейнер успешно запущен'
                
                # Ждем полной инициализации
                sleep 5
                
                # Проверяем доступность порта 8080
                if ss -tlnp | grep -q ':8080'; then
                    log_step 'Порт 8080 открыт и готов к подключению'
                else
                    log_step 'WARNING: Порт 8080 пока недоступен, может потребоваться время'
                fi
                
                log_step 'installation completed successfully'
                
                echo
                echo '╔══════════════════════════════════════════════════════════════════════════╗'
                echo '║                          УСТАНОВКА ЗАВЕРШЕНА!                           ║'
                echo '╚══════════════════════════════════════════════════════════════════════════╝'
                echo
                if [ -n \"\$VPS_IP\" ]; then
                    echo \"🌐 AIO Панель управления: http://\$VPS_IP:8080\"
                    echo \"🔗 Nextcloud (после настройки): http://\$VPS_IP:8443\"
                else
                    echo '🌐 AIO Панель управления: http://YOUR_IP:8080'
                    echo '🔗 Nextcloud (после настройки): http://YOUR_IP:8443'
                fi
                echo
                echo '📋 Следующие шаги:'
                echo '   1. Откройте панель управления в браузере'
                echo '   2. Настройте папку для резервных копий'
                echo '   3. Выберите дополнительные контейнеры'
                echo '   4. Нажмите \"Start containers\"'
            else
                log_error 'Контейнер не запустился. Проверьте логи: docker logs $CONTAINER_NAME'
                exit 1
            fi
            
            rm -f '$PID_FILE'
            echo
            echo 'Нажмите Ctrl+A, D для отключения или Enter для закрытия'
            read
        "
        
        sleep 3
        echo -e "${GREEN}${CHECKMARK} Установка запущена в защищенной screen-сессии${NC}"
        echo -e "${BLUE}${INFO} Сессия: '$SCREEN_SESSION'${NC}"
        echo
        echo -e "${CYAN}Доступные команды:${NC}"
        echo -e "  ${WHITE}Подключиться:${NC} screen -r $SCREEN_SESSION"
        echo -e "  ${WHITE}Отключиться:${NC} Ctrl+A, D"
        echo
        
        echo -n "Подключиться к процессу установки сейчас? (Y/n): "
        read -r connect_now
        if [[ ! $connect_now =~ ^[Nn]$ ]]; then
            connect_to_installation
        fi
    fi
}

connect_to_installation() {
    local install_status
    install_status=$(get_install_status)
    
    case $install_status in
        "running")
            echo -e "${BLUE}${INFO} Подключение к процессу установки...${NC}"
            echo -e "${BLUE}${INFO} Для отключения используйте: Ctrl+A, D${NC}"
            sleep 2
            screen -r "$SCREEN_SESSION"
            ;;
        "completed")
            echo -e "${GREEN}${CHECKMARK} Установка уже завершена${NC}"
            show_access_info
            ;;
        "failed")
            echo -e "${RED}${CROSS} Установка завершилась с ошибкой${NC}"
            show_install_logs
            ;;
        *)
            echo -e "${RED}${CROSS} Установка не запущена${NC}"
            ;;
    esac
}

show_install_logs() {
    if [ ! -f "$INSTALL_LOG" ]; then
        echo -e "${RED}${CROSS} Файл логов не найден${NC}"
        return
    fi
    
    print_banner
    echo -e "${CYAN}"
    echo "┌─────────────────────────── ${WHITE}ЛОГИ УСТАНОВКИ${CYAN} ───────────────────────────┐"
    
    tail -20 "$INSTALL_LOG" | while IFS= read -r line; do
        if [[ $line == *"ERROR"* ]] || [[ $line == *"FAILED"* ]]; then
            echo -e "${RED}$line${NC}"
        elif [[ $line == *"SUCCESS"* ]] || [[ $line == *"completed"* ]]; then
            echo -e "${GREEN}$line${NC}"
        elif [[ $line == *"WARNING"* ]]; then
            echo -e "${YELLOW}$line${NC}"
        else
            echo "$line"
        fi
    done
    
    echo -e "${CYAN}└──────────────────────────────────────────────────────────────────────┘${NC}\n"
    
    local install_status
    install_status=$(get_install_status)
    if [ "$install_status" = "running" ]; then
        echo -n "Показать логи в реальном времени? (y/N): "
        read -r confirm
        if [[ $confirm =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}${INFO} Логи в реальном времени (Ctrl+C для выхода)...${NC}"
            tail -f "$INSTALL_LOG"
        fi
    fi
}

restart_installation() {
    echo -e "${YELLOW}${WARNING} Это остановит текущую установку и запустит заново${NC}"
    echo -n "Продолжить? (y/N): "
    read -r confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}${GEAR} Остановка текущей установки...${NC}"
        
        screen -S "$SCREEN_SESSION" -X quit 2>/dev/null || true
        rm -f "$PID_FILE"
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
        docker rm "$CONTAINER_NAME" 2>/dev/null || true
        
        echo -e "${GREEN}${CHECKMARK} Предыдущая установка остановлена${NC}"
        sleep 2
        start_installation
    fi
}

show_access_info() {
    print_banner
    detect_ip
    
    echo -e "${GREEN}"
    echo "┌─────────────────────── ${WHITE}ИНФОРМАЦИЯ О ДОСТУПЕ${GREEN} ─────────────────────────┐"
    
    if [ -n "$VPS_IP" ]; then
        echo -e "│  ${CLOUD}${CYAN} AIO Панель управления:${NC}                                     ${GREEN}│"
        echo -e "│     ${WHITE}http://$VPS_IP:8080${NC}                                          ${GREEN}│"
        echo -e "│                                                                      ${GREEN}│"
        echo -e "│  ${CHECKMARK}${CYAN} Nextcloud (после настройки):${NC}                              ${GREEN}│"
        echo -e "│     ${WHITE}http://$VPS_IP:8443${NC}                                          ${GREEN}│"
    else
        echo -e "│  ${WARNING}${YELLOW} IP адрес не определен${NC}                                       ${GREEN}│"
        echo -e "│     Используйте: ${WHITE}http://YOUR_IP:8080${NC}                              ${GREEN}│"
    fi
    
    echo -e "│                                                                      ${GREEN}│"
    echo -e "│  ${INFO}${BLUE} Следующие шаги:${NC}                                              ${GREEN}│"
    echo -e "│     1. Откройте панель управления в браузере                       ${GREEN}│"
    echo -e "│     2. Настройте папку для резервных копий                         ${GREEN}│"
    echo -e "│     3. Выберите дополнительные контейнеры                          ${GREEN}│"
    echo -e "│     4. Нажмите \"Start containers\"                                  ${GREEN}│"
    echo -e "└──────────────────────────────────────────────────────────────────────┘${NC}\n"
}

show_container_management() {
    local status
    status=$(get_container_status)
    
    print_banner
    echo -e "${BLUE}"
    echo "┌─────────────────────── ${WHITE}УПРАВЛЕНИЕ КОНТЕЙНЕРОМ${BLUE} ──────────────────────────┐"
    
    case $status in
        "running")
            echo -e "│  ${CHECKMARK}${GREEN} Контейнер активен и работает${NC}                              ${BLUE}│"
            echo -e "│                                                                      ${BLUE}│"
            echo -e "│  ${YELLOW}1${NC} Остановить контейнер                                       ${BLUE}│"
            echo -e "│  ${YELLOW}2${NC} Перезапустить контейнер                                    ${BLUE}│"
            echo -e "│  ${BLUE}3${NC} Показать логи контейнера                                   ${BLUE}│"
            ;;
        "stopped")
            echo -e "│  ${WARNING}${YELLOW} Контейнер остановлен${NC}                                      ${BLUE}│"
            echo -e "│                                                                      ${BLUE}│"
            echo -e "│  ${GREEN}1${NC} Запустить контейнер                                        ${BLUE}│"
            echo -e "│  ${RED}2${NC} Удалить контейнер                                          ${BLUE}│"
            ;;
        *)
            echo -e "│  ${CROSS}${RED} Контейнер не найден${NC}                                       ${BLUE}│"
            echo -e "│                                                                      ${BLUE}│"
            echo -e "│  Сначала выполните установку                                       ${BLUE}│"
            ;;
    esac
    
    echo -e "│                                                                      ${BLUE}│"
    echo -e "│  ${GRAY}0${NC} Назад                                                          ${BLUE}│"
    echo -e "└──────────────────────────────────────────────────────────────────────┘${NC}\n"
    echo -e "${CYAN}Выберите опцию:${NC} "
    
    read -r choice
    case $choice in
        1)
            if [ "$status" = "running" ]; then
                docker stop "$CONTAINER_NAME"
                echo -e "${GREEN}${CHECKMARK} Контейнер остановлен${NC}"
            elif [ "$status" = "stopped" ]; then
                docker start "$CONTAINER_NAME"
                echo -e "${GREEN}${CHECKMARK} Контейнер запущен${NC}"
            fi
            ;;
        2)
            if [ "$status" = "running" ]; then
                docker restart "$CONTAINER_NAME"
                echo -e "${GREEN}${CHECKMARK} Контейнер перезапущен${NC}"
            elif [ "$status" = "stopped" ]; then
                docker rm "$CONTAINER_NAME"
                echo -e "${GREEN}${CHECKMARK} Контейнер удален${NC}"
            fi
            ;;
        3)
            if [ "$status" = "running" ]; then
                echo -e "${BLUE}${INFO} Логи контейнера (последние 20 строк):${NC}"
                docker logs --tail 20 "$CONTAINER_NAME"
            fi
            ;;
    esac
    
    if [ "$choice" != "0" ]; then
        echo -n "Нажмите Enter для продолжения..."
        read -r
    fi
}

show_diagnostics() {
    print_banner
    echo -e "${YELLOW}"
    echo "┌─────────────────────────── ${WHITE}ДИАГНОСТИКА${YELLOW} ──────────────────────────────┐"
    
    # Docker статус
    if systemctl is-active --quiet docker; then
        echo -e "│  ${CHECKMARK}${GREEN} Docker Service: Активен${NC}                                   ${YELLOW}│"
    else
        echo -e "│  ${CROSS}${RED} Docker Service: Неактивен${NC}                                 ${YELLOW}│"
    fi
    
    # Порты
    echo -e "│  ${INFO}${BLUE} Открытые порты:${NC}                                             ${YELLOW}│"
    if ss -tlnp | grep -q ":8080"; then
        echo -e "│    ${CHECKMARK} 8080 (AIO Panel)                                           ${YELLOW}│"
    else
        echo -e "│    ${CROSS} 8080 (AIO Panel) - не открыт                               ${YELLOW}│"
    fi
    
    # Память
    local mem_total
    local mem_used
    mem_total=$(free -h | awk '/^Mem:/{print $2}')
    mem_used=$(free -h | awk '/^Mem:/{print $3}')
    echo -e "│  ${INFO}${BLUE} Память: ${mem_used}/${mem_total}${NC}                                        ${YELLOW}│"
    
    # Диск
    local disk_info
    disk_info=$(df -h / | awk 'NR==2{print $3"/"$2" ("$5" используется)"}')
    echo -e "│  ${INFO}${BLUE} Диск: ${disk_info}${NC}                                ${YELLOW}│"
    
    echo -e "└──────────────────────────────────────────────────────────────────────┘${NC}\n"
    
    echo -n "Нажмите Enter для продолжения..."
    read -r
}

# ═══════════════════════════════════════════════════════════════════════════════
# 🎯 ГЛАВНАЯ ФУНКЦИЯ
# ═══════════════════════════════════════════════════════════════════════════════

main_loop() {
    while true; do
        print_banner
        detect_ip
        print_status_box
        print_menu
        
        read -r choice
        
        local install_status
        local container_status
        install_status=$(get_install_status)
        container_status=$(get_container_status)
        
        case $choice in
            1)
                if [ "$install_status" = "not_started" ] || [ "$install_status" = "failed" ]; then
                    start_installation
                elif [ "$install_status" = "running" ]; then
                    connect_to_installation
                elif [ "$install_status" = "completed" ] && [ "$container_status" = "running" ]; then
                    show_container_management
                elif [ "$install_status" = "completed" ] && [ "$container_status" != "running" ]; then
                    # Запуск остановленного контейнера
                    echo -e "${BLUE}${GEAR} Запуск контейнера Nextcloud AIO...${NC}"
                    if docker start "$CONTAINER_NAME" &>/dev/null; then
                        echo -e "${GREEN}${CHECKMARK} Контейнер успешно запущен${NC}"
                        sleep 2
                    else
                        echo -e "${RED}${CROSS} Ошибка запуска контейнера${NC}"
                        sleep 2
                    fi
                fi
                ;;
            2)
                if [ "$install_status" = "running" ]; then
                    show_install_logs
                elif [ "$install_status" = "not_started" ] || [ "$install_status" = "failed" ]; then
                    show_diagnostics
                else
                    show_access_info
                    echo -n "Нажмите Enter для продолжения..."
                    read -r
                fi
                ;;
            3)
                if [ "$install_status" = "running" ]; then
                    restart_installation
                else
                    show_diagnostics
                fi
                ;;
            4)
                if [ "$install_status" = "completed" ]; then
                    restart_installation
                fi
                ;;
            0)
                echo -e "${BLUE}${INFO} Выход из программы${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}${CROSS} Неверный выбор${NC}"
                sleep 2
                ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# 🚀 ЗАПУСК ПРОГРАММЫ
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    check_root
    detect_os
    update_system
    install_dependencies
    mkdir -p "$(dirname "$INSTALL_LOG")" 2>/dev/null || true
    main_loop
}

# Запуск только при прямом выполнении (не через source)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
