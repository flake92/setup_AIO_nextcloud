#!/bin/bash

# 🌟 Nextcloud AIO - Красивое интерактивное меню
# Полностью автоматизированная установка с защитой от отключения SSH

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
INSTALL_LOG="/var/log/nextcloud-aio.log"
SCREEN_SESSION="nextcloud-aio"
CONTAINER_NAME="nextcloud-aio-mastercontainer"
PID_FILE="/var/run/nextcloud-aio.pid"
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
    local container_status=$(get_container_status)
    local install_status=$(get_install_status)
    local progress=$(get_install_progress)
    
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
    
    local install_status=$(get_install_status)
    
    if [ "$install_status" = "not_started" ] || [ "$install_status" = "failed" ]; then
        echo -e "│  ${ROCKET}${GREEN} 1${NC} ${GREEN}Запустить автоматическую установку${NC}                       ${WHITE}│"
    elif [ "$install_status" = "running" ]; then
        echo -e "│  ${GEAR}${BLUE} 1${NC} ${BLUE}Подключиться к процессу установки${NC}                        ${WHITE}│"
        echo -e "│  ${INFO}${YELLOW} 2${NC} ${YELLOW}Показать логи установки${NC}                                  ${WHITE}│"
        echo -e "│  ${CROSS}${RED} 3${NC} ${RED}Перезапустить установку${NC}                                  ${WHITE}│"
    else
        echo -e "│  ${CHECKMARK}${GREEN} 1${NC} ${GREEN}Управление контейнером${NC}                                   ${WHITE}│"
        echo -e "│  ${INFO}${BLUE} 2${NC} ${BLUE}Показать информацию о доступе${NC}                             ${WHITE}│"
        echo -e "│  ${GEAR}${YELLOW} 3${NC} ${YELLOW}Диагностика системы${NC}                                      ${WHITE}│"
        echo -e "│  ${ROCKET}${PURPLE} 4${NC} ${PURPLE}Переустановить Nextcloud AIO${NC}                             ${WHITE}│"
    fi
    
    echo -e "│                                                                      ${WHITE}│"
    echo -e "│  ${GRAY} 0${NC} ${GRAY}Выход${NC}                                                        ${WHITE}│"
    echo -e "└──────────────────────────────────────────────────────────────────────┘${NC}\n"
    echo -e "${CYAN}Выберите опцию:${NC} "
}

# ═══════════════════════════════════════════════════════════════════════════════
# 🔧 СИСТЕМНЫЕ ФУНКЦИИ
# ═══════════════════════════════════════════════════════════════════════════════

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}${CROSS} Требуются права root. Перезапуск с sudo...${NC}"
        exec sudo "$0" "$@"
    fi
}

check_debian() {
    if [ ! -f /etc/debian_version ]; then
        echo -e "${RED}${CROSS} Этот скрипт предназначен только для Debian/Ubuntu${NC}"
        exit 1
    fi
    
    local debian_version=$(cat /etc/debian_version | cut -d. -f1)
    if [ "$debian_version" -lt 11 ]; then
        echo -e "${YELLOW}${WARNING} Обнаружена старая версия Debian ($debian_version). Рекомендуется Debian 11+${NC}"
    fi
}

update_system() {
    echo -e "${BLUE}${GEAR} Обновление системы...${NC}"
    
    # Обновляем список пакетов
    if ! apt-get update -qq; then
        echo -e "${RED}${CROSS} Ошибка обновления списка пакетов${NC}"
        exit 1
    fi
    
    # Устанавливаем базовые пакеты если их нет
    local packages="curl wget gnupg lsb-release ca-certificates apt-transport-https software-properties-common"
    
    for package in $packages; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            echo -e "${BLUE}${GEAR} Установка $package...${NC}"
            if ! apt-get install -y "$package" &>/dev/null; then
                echo -e "${RED}${CROSS} Ошибка установки $package${NC}"
                exit 1
            fi
        fi
    done
    
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
        if ! apt-get install -y $missing_packages &>/dev/null; then
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
        local pid=$(cat "$PID_FILE")
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
    local install_status=$(get_install_status)
    
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
        > "$INSTALL_LOG"
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
            log_step 'Проверка системы Debian...'
            if [ ! -f /etc/debian_version ]; then
                log_error 'Система не является Debian/Ubuntu'
                exit 1
            fi
            
            debian_version=\$(cat /etc/debian_version | cut -d. -f1)
            log_step \"Обнаружена Debian версии: \$debian_version\"
            
            # Обновление системы
            log_step 'Обновление системы и установка базовых пакетов...'
            export DEBIAN_FRONTEND=noninteractive
            
            if ! apt-get update -qq; then
                log_error 'Ошибка обновления списка пакетов'
                exit 1
            fi
            
            # Устанавливаем базовые пакеты
            base_packages=\"curl wget gnupg lsb-release ca-certificates apt-transport-https software-properties-common\"
            if ! apt-get install -y \$base_packages &>/dev/null; then
                log_error 'Ошибка установки базовых пакетов'
                exit 1
            fi
            
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
            
            # Установка Docker
            log_step 'Установка Docker...'
            
            # Удаляем старые версии если есть
            apt-get remove -y docker docker-engine docker.io containerd runc &>/dev/null || true
            
            # Добавляем GPG ключ Docker
            mkdir -p /etc/apt/keyrings
            if ! curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null; then
                log_error 'Ошибка добавления GPG ключа Docker'
                exit 1
            fi
            
            # Добавляем репозиторий Docker для Debian
            echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \$(lsb_release -cs) stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Обновляем и устанавливаем Docker
            if ! apt-get update -qq; then
                log_error 'Ошибка обновления после добавления репозитория Docker'
                exit 1
            fi
            
            if ! apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin &>/dev/null; then
                log_error 'Ошибка установки Docker'
                exit 1
            fi
            
            log_step 'Настройка Docker...'
            
            # Запускаем и включаем Docker
            if ! systemctl start docker; then
                log_error 'Ошибка запуска Docker'
                exit 1
            fi
            
            if ! systemctl enable docker &>/dev/null; then
                log_error 'Ошибка включения автозапуска Docker'
                exit 1
            fi
            
            # Проверяем что Docker работает
            if ! docker --version &>/dev/null; then
                log_error 'Docker не работает корректно'
                exit 1
            fi
            
            log_step 'Docker успешно установлен и настроен'
            
            log_step 'Запуск Nextcloud AIO контейнера...'
            
            # Останавливаем старый контейнер если есть
            docker stop '$CONTAINER_NAME' 2>/dev/null || true
            docker rm '$CONTAINER_NAME' 2>/dev/null || true
            
            # Скачиваем образ заранее
            if ! docker pull nextcloud/all-in-one:latest &>/dev/null; then
                log_error 'Ошибка загрузки образа Nextcloud AIO'
                exit 1
            fi
            
            # Запускаем контейнер
            if ! docker run \\
                --init \\
                --sig-proxy=false \\
                --name '$CONTAINER_NAME' \\
                --restart always \\
                --publish 80:80 \\
                --publish 8080:8080 \\
                --publish 8443:8443 \\
                --publish 3478:3478/tcp \\
                --publish 3478:3478/udp \\
                --volume nextcloud_aio_mastercontainer:/mnt/docker-aio-config \\
                --volume /var/run/docker.sock:/var/run/docker.sock:ro \\
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
    local install_status=$(get_install_status)
    
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
    
    local install_status=$(get_install_status)
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
    local status=$(get_container_status)
    
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
    local mem_total=$(free -h | awk '/^Mem:/{print $2}')
    local mem_used=$(free -h | awk '/^Mem:/{print $3}')
    echo -e "│  ${INFO}${BLUE} Память: ${mem_used}/${mem_total}${NC}                                        ${YELLOW}│"
    
    # Диск
    local disk_info=$(df -h / | awk 'NR==2{print $3"/"$2" ("$5" используется)"}')
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
        
        case $choice in
            1)
                local install_status=$(get_install_status)
                if [ "$install_status" = "not_started" ] || [ "$install_status" = "failed" ]; then
                    start_installation
                elif [ "$install_status" = "running" ]; then
                    connect_to_installation
                else
                    show_container_management
                fi
                ;;
            2)
                local install_status=$(get_install_status)
                if [ "$install_status" = "running" ]; then
                    show_install_logs
                else
                    show_access_info
                fi
                echo -n "Нажмите Enter для продолжения..."
                read -r
                ;;
            3)
                local install_status=$(get_install_status)
                if [ "$install_status" = "running" ]; then
                    restart_installation
                else
                    show_diagnostics
                fi
                ;;
            4)
                local install_status=$(get_install_status)
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
    check_debian
    update_system
    install_dependencies
    mkdir -p "$(dirname "$INSTALL_LOG")" 2>/dev/null || true
    main_loop
}

# Запуск
main "$@"
