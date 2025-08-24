#!/bin/bash

# 🌟 Nextcloud AIO - Простая рабочая версия
# Минимальный скрипт для быстрой установки

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Символы
CHECKMARK="✅"
CROSS="❌"
WARNING="⚠️"
INFO="ℹ️"
GEAR="⚙️"

echo -e "${BLUE}🌟 Nextcloud AIO - Простая установка${NC}\n"

# Проверка root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}${CROSS} Требуются права root${NC}"
    exec sudo "$0"
fi

# Определение системы
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo -e "${INFO} Система: $PRETTY_NAME"
else
    echo -e "${RED}${CROSS} Неподдерживаемая система${NC}"
    exit 1
fi

# Очистка старых репозиториев Docker
echo -e "${GEAR} Очистка старых настроек..."
rm -f /etc/apt/sources.list.d/docker.list
rm -f /etc/apt/keyrings/docker.gpg

# Обновление системы
echo -e "${GEAR} Обновление системы..."
apt-get update -qq
apt-get install -y curl wget ca-certificates gnupg lsb-release

# Установка Docker
echo -e "${GEAR} Установка Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl start docker
    systemctl enable docker
    echo -e "${CHECKMARK} Docker установлен"
else
    echo -e "${CHECKMARK} Docker уже установлен"
fi

# Получение IP
echo -e "${GEAR} Определение IP адреса..."
VPS_IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || echo "localhost")
echo -e "${INFO} IP адрес: $VPS_IP"

# Остановка старого контейнера
echo -e "${GEAR} Очистка старых контейнеров..."
docker stop nextcloud-aio 2>/dev/null || true
docker rm nextcloud-aio 2>/dev/null || true

# Запуск Nextcloud AIO
echo -e "${GEAR} Запуск Nextcloud AIO..."
docker run -d \
    --name nextcloud-aio \
    --restart always \
    -p 8080:8080 \
    -e APACHE_PORT=11000 \
    -e APACHE_IP_BINDING=0.0.0.0 \
    -v nextcloud_aio_mastercontainer:/mnt/docker-aio-config \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    nextcloud/all-in-one:latest

# Ожидание запуска
echo -e "${GEAR} Ожидание запуска контейнера..."
sleep 10

# Проверка статуса
if docker ps | grep -q nextcloud-aio; then
    echo -e "\n${CHECKMARK} ${GREEN}Nextcloud AIO успешно запущен!${NC}\n"
    echo -e "${INFO} Панель управления: ${BLUE}http://$VPS_IP:8080${NC}"
    echo -e "${INFO} Для настройки откройте ссылку в браузере"
    echo -e "\n${WARNING} Сохраните пароль администратора из веб-интерфейса!"
else
    echo -e "\n${CROSS} ${RED}Ошибка запуска контейнера${NC}"
    echo -e "${INFO} Проверьте логи: ${YELLOW}docker logs nextcloud-aio${NC}"
    exit 1
fi

echo -e "\n${CHECKMARK} ${GREEN}Установка завершена!${NC}"
