#!/bin/bash

# 🚀 Nextcloud AIO - Автоматическая установка для Debian 12
# Устанавливает Docker, обновляет систему и запускает Nextcloud All-in-One

set -euo pipefail

# 🎨 Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 📋 Проверка root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Запустите от root: $0${NC}"
    exit 1
fi

# 🎯 Интерактивное меню
show_menu() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║               🚀 Nextcloud AIO Installer                  ║${NC}"
    echo -e "${CYAN}║                    Debian 12 Edition                     ║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║                                                           ║${NC}"
    echo -e "${CYAN}║  ${GREEN}1)${NC} Полная установка (рекомендуется)                  ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${GREEN}2)${NC} Только обновить систему                           ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${GREEN}3)${NC} Только установить Docker                          ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${GREEN}4)${NC} Только запустить Nextcloud AIO                    ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${GREEN}5)${NC} Запустить в screen сессии                         ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${BLUE}6)${NC} Проверить статус установки                        ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${RED}0)${NC} Выход                                             ${CYAN}║${NC}"
    echo -e "${CYAN}║                                                           ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${YELLOW}Выберите опцию [0-6]:${NC} "
}

# 🔄 Обновление системы
update_system() {
    echo -e "${BLUE}📦 Обновление системы...${NC}"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get upgrade -y -qq
    apt-get install -y -qq curl wget ca-certificates gnupg lsb-release htop screen \
        nano vim git unzip zip tree ncdu iotop nethogs nload \
        net-tools dnsutils iputils-ping traceroute tcpdump \
        fail2ban ufw logrotate rsync cron
    
    # Настройка базовой безопасности
    echo -e "${BLUE}🔒 Настройка базовой безопасности...${NC}"
    
    # Настройка UFW для Nextcloud AIO
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    
    # SSH (обязательно первым!)
    ufw allow ssh
    ufw allow 22/tcp
    
    # Nextcloud AIO основные порты
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'
    ufw allow 8080/tcp comment 'AIO Interface HTTP'
    ufw allow 8443/tcp comment 'AIO Interface HTTPS'
    
    # Talk (видеозвонки)
    ufw allow 3478/tcp comment 'Talk TURN TCP'
    ufw allow 3478/udp comment 'Talk TURN UDP'
    ufw allow 10000:20000/udp comment 'Talk RTP'
    
    # Дополнительные порты для внешних сервисов (если нужны)
    # ufw allow 5432/tcp comment 'PostgreSQL'
    # ufw allow 6379/tcp comment 'Redis'
    # ufw allow 9000/tcp comment 'PHP-FPM'
    
    # Включаем UFW
    ufw --force enable
    
    # Показываем статус
    echo -e "${GREEN}🔥 Статус UFW:${NC}"
    ufw status numbered
    
    # Настройка fail2ban для SSH защиты
    systemctl enable fail2ban
    systemctl start fail2ban
    
    # Создаем конфиг для защиты SSH
    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 7200

[nginx-http-auth]
enabled = false

[nginx-noscript]
enabled = false
EOF
    
    # Перезапускаем fail2ban
    systemctl restart fail2ban
    
    echo -e "${GREEN}🛡️  Fail2ban настроен для защиты SSH${NC}"
    
    echo -e "${GREEN}✅ Система обновлена и защищена${NC}"
}

# 🐳 Установка Docker
install_docker() {
    echo -e "${BLUE}🐳 Установка Docker...${NC}"
    
    # Удаляем старые версии
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Добавляем репозиторий Docker
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
    
    # Устанавливаем Docker
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Запускаем Docker
    systemctl enable docker
    systemctl start docker
    
    echo -e "${GREEN}✅ Docker установлен: $(docker --version | cut -d' ' -f3 | tr -d ',')${NC}"
}

# 🚀 Запуск Nextcloud AIO
run_nextcloud_aio() {
    echo -e "${BLUE}🚀 Запуск Nextcloud AIO...${NC}"
    
    # Получаем IP
    echo -e "${BLUE}🌐 Определение IP адреса...${NC}"
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "localhost")
    echo -e "${GREEN}✅ IP: $SERVER_IP${NC}"
    
    # Останавливаем существующий контейнер
    docker stop nextcloud-aio-mastercontainer 2>/dev/null || true
    docker rm nextcloud-aio-mastercontainer 2>/dev/null || true
    
    # Запускаем новый контейнер
    docker run \
        --init \
        --sig-proxy=false \
        --name nextcloud-aio-mastercontainer \
        --restart always \
        --publish 80:80 \
        --publish 8080:8080 \
        --publish 8443:8443 \
        --volume nextcloud_aio_mastercontainer:/mnt/docker-aio-config \
        --volume /var/run/docker.sock:/var/run/docker.sock:ro \
        --detach \
        ghcr.io/nextcloud-releases/all-in-one:latest
    
    # Проверяем запуск
    sleep 5
    if docker ps | grep -q nextcloud-aio-mastercontainer; then
        echo -e "${GREEN}✅ Nextcloud AIO запущен успешно!${NC}"
        show_access_info
    else
        echo -e "${RED}❌ Ошибка запуска${NC}"
        docker logs nextcloud-aio-mastercontainer 2>/dev/null || true
        exit 1
    fi
}

# 📋 Информация для доступа
show_access_info() {
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "localhost")
    echo
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                🎉 УСТАНОВКА ЗАВЕРШЕНА!                   ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${BLUE}📋 Доступ к Nextcloud AIO:${NC}"
    echo -e "   🌐 HTTP:  ${YELLOW}http://$SERVER_IP:8080${NC}"
    echo -e "   🔒 HTTPS: ${YELLOW}https://$SERVER_IP:8443${NC}"
    echo
    echo -e "${BLUE}🔧 Управление Docker:${NC}"
    echo -e "   📊 Статус:     ${GREEN}docker ps${NC}"
    echo -e "   📝 Логи:       ${GREEN}docker logs nextcloud-aio-mastercontainer${NC}"
    echo -e "   🔄 Перезапуск: ${GREEN}docker restart nextcloud-aio-mastercontainer${NC}"
    echo -e "   🛑 Остановка:  ${RED}docker stop nextcloud-aio-mastercontainer${NC}"
    echo
    show_next_steps
}

# 🎯 Следующие шаги
show_next_steps() {
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    🚀 ЧТО ДЕЛАТЬ ДАЛЬШЕ?                 ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${YELLOW}1. Откройте браузер и перейдите по ссылке:${NC}"
    echo -e "   ${GREEN}https://$SERVER_IP:8443${NC} ${BLUE}(рекомендуется)${NC}"
    echo -e "   ${GREEN}http://$SERVER_IP:8080${NC} ${YELLOW}(если HTTPS не работает)${NC}"
    echo
    echo -e "${YELLOW}2. При первом входе:${NC}"
    echo -e "   • Согласитесь с предупреждением о сертификате"
    echo -e "   • Создайте администратора Nextcloud"
    echo -e "   • Выберите нужные приложения для установки"
    echo -e "   • ${RED}Отключите OnlyOffice, Talk, Whiteboard${NC} ${BLUE}(для слабого VPS)${NC}"
    echo
    echo -e "${YELLOW}3. Полезные команды:${NC}"
    echo -e "   • Мониторинг: ${GREEN}htop${NC}, ${GREEN}ncdu${NC}, ${GREEN}nethogs${NC}"
    echo -e "   • Логи: ${GREEN}docker logs -f nextcloud-aio-mastercontainer${NC}"
    echo -e "   • Файрвол: ${GREEN}ufw status${NC}"
    echo -e "   • Screen: ${GREEN}screen -r nextcloud-install${NC} ${BLUE}(если запускали в screen)${NC}"
    echo
    echo -e "${YELLOW}4. Безопасность:${NC}"
    echo -e "   • UFW настроен и активен"
    echo -e "   • Fail2ban защищает SSH"
    echo -e "   • Смените пароль root: ${GREEN}passwd${NC}"
    echo -e "   • Настройте SSH ключи вместо паролей"
    echo
    echo -e "${YELLOW}5. Если что-то не работает:${NC}"
    echo -e "   • Проверьте статус: ${GREEN}docker ps -a${NC}"
    echo -e "   • Перезапустите: ${GREEN}docker restart nextcloud-aio-mastercontainer${NC}"
    echo -e "   • Проверьте порты: ${GREEN}netstat -tulpn | grep -E ':(80|443|8080|8443)'${NC}"
    echo
    echo -e "${GREEN}✨ Готово! Ваш Nextcloud AIO готов к работе!${NC}"
    echo -e "${BLUE}📚 Документация: https://github.com/nextcloud/all-in-one${NC}"
    echo
}

# 🔍 Проверка статуса установки
check_installation_status() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                📊 СТАТУС УСТАНОВКИ                       ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Проверка Docker
    echo -e "${BLUE}🐳 Docker:${NC}"
    if command -v docker &> /dev/null; then
        echo -e "   ✅ Установлен: $(docker --version | cut -d' ' -f3 | tr -d ',')"
        if systemctl is-active --quiet docker; then
            echo -e "   ✅ Запущен"
        else
            echo -e "   ❌ Не запущен"
        fi
    else
        echo -e "   ❌ Не установлен"
    fi
    echo
    
    # Проверка Nextcloud AIO
    echo -e "${BLUE}☁️  Nextcloud AIO:${NC}"
    if docker ps | grep -q nextcloud-aio-mastercontainer; then
        echo -e "   ✅ Мастер-контейнер запущен"
        SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "localhost")
        echo -e "   🌐 Доступ: ${GREEN}https://$SERVER_IP:8443${NC}"
        echo -e "   🌐 Доступ: ${GREEN}http://$SERVER_IP:8080${NC}"
    elif docker ps -a | grep -q nextcloud-aio-mastercontainer; then
        echo -e "   ⚠️  Мастер-контейнер остановлен"
        echo -e "   💡 Запустить: ${GREEN}docker start nextcloud-aio-mastercontainer${NC}"
    else
        echo -e "   ❌ Мастер-контейнер не найден"
    fi
    echo
    
    # Проверка других контейнеров AIO
    echo -e "${BLUE}📦 Контейнеры AIO:${NC}"
    if docker ps -a | grep -q nextcloud-aio; then
        docker ps -a --format "table {{.Names}}\t{{.Status}}" | grep nextcloud-aio | while read line; do
            name=$(echo $line | awk '{print $1}')
            status=$(echo $line | awk '{print $2}')
            if [[ $status == "Up" ]]; then
                echo -e "   ✅ $name"
            else
                echo -e "   ❌ $name ($status)"
            fi
        done
    else
        echo -e "   ❌ Контейнеры AIO не найдены"
    fi
    echo
    
    # Проверка портов
    echo -e "${BLUE}🔌 Порты:${NC}"
    for port in 80 443 8080 8443 3478; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            echo -e "   ✅ Порт $port открыт"
        else
            echo -e "   ❌ Порт $port закрыт"
        fi
    done
    echo
    
    # Проверка UFW
    echo -e "${BLUE}🔥 Файрвол UFW:${NC}"
    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            echo -e "   ✅ Активен"
        else
            echo -e "   ❌ Неактивен"
        fi
    else
        echo -e "   ❌ Не установлен"
    fi
    echo
    
    echo -e "${GREEN}Нажмите Enter для возврата в меню...${NC}"
    read -r
}

# 📺 Запуск в screen
run_in_screen() {
    echo -e "${BLUE}📺 Запуск в screen сессии...${NC}"
    screen -dmS nextcloud-install bash -c "$0 --full-install; exec bash"
    echo -e "${GREEN}✅ Установка запущена в screen сессии 'nextcloud-install'${NC}"
    echo -e "${YELLOW}Подключиться: screen -r nextcloud-install${NC}"
    echo -e "${YELLOW}Отключиться: Ctrl+A, затем D${NC}"
}

# 🛡️ Проверка на повторную установку
check_existing_installation() {
    if docker ps -a | grep -q nextcloud-aio-mastercontainer; then
        echo -e "${YELLOW}⚠️  Обнаружена существующая установка Nextcloud AIO!${NC}"
        echo
        if docker ps | grep -q nextcloud-aio-mastercontainer; then
            echo -e "${GREEN}✅ Мастер-контейнер уже запущен${NC}"
            SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "localhost")
            echo -e "   🌐 Доступ: ${GREEN}https://$SERVER_IP:8443${NC}"
        else
            echo -e "${YELLOW}⚠️  Мастер-контейнер остановлен${NC}"
            echo -e "${BLUE}Хотите запустить существующий контейнер? (y/n):${NC} "
            read -r response
            if [[ $response =~ ^[Yy]$ ]]; then
                docker start nextcloud-aio-mastercontainer
                echo -e "${GREEN}✅ Контейнер запущен${NC}"
                show_access_info
                return 0
            fi
        fi
        echo
        echo -e "${RED}Продолжение установки перезапишет существующую конфигурацию!${NC}"
        echo -e "${BLUE}Продолжить? (y/n):${NC} "
        read -r response
        if [[ ! $response =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Установка отменена${NC}"
            return 1
        fi
    fi
    return 0
}

# 🎯 Полная установка
full_install() {
    echo -e "${BLUE}🚀 Начинаем полную установку Nextcloud AIO на Debian 12${NC}"
    echo
    
    # Проверяем существующую установку
    if ! check_existing_installation; then
        return
    fi
    
    update_system
    install_docker
    run_nextcloud_aio
}

# 🎮 Основной цикл меню
main_menu() {
    while true; do
        show_menu
        read -r choice
        
        case $choice in
            1)
                full_install
                break
                ;;
            2)
                update_system
                echo -e "${GREEN}Нажмите Enter для возврата в меню...${NC}"
                read -r
                ;;
            3)
                install_docker
                echo -e "${GREEN}Нажмите Enter для возврата в меню...${NC}"
                read -r
                ;;
            4)
                run_nextcloud_aio
                break
                ;;
            5)
                run_in_screen
                break
                ;;
            6)
                check_installation_status
                ;;
            0)
                echo -e "${GREEN}До свидания!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Неверный выбор. Попробуйте снова.${NC}"
                sleep 2
                ;;
        esac
    done
}

# 🎬 Запуск
if [[ "${1:-}" == "--full-install" ]]; then
    full_install
else
    main_menu
fi
