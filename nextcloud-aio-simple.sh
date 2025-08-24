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

# Открытие порта в firewall
echo -e "${GEAR} Настройка firewall..."
if command -v ufw &> /dev/null; then
    ufw allow 8080/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
fi

# Запуск Nextcloud AIO
echo -e "${GEAR} Запуск Nextcloud AIO..."
docker run -d \
    --name nextcloud-aio \
    --restart always \
    -p 8080:8080 \
    -p 8443:8443 \
    -e APACHE_PORT=11000 \
    -e APACHE_IP_BINDING=0.0.0.0 \
    -v nextcloud_aio_mastercontainer:/mnt/docker-aio-config \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    nextcloud/all-in-one:latest

# Ожидание запуска
echo -e "${GEAR} Ожидание запуска контейнера..."
sleep 15

# Диагностика
echo -e "${INFO} Диагностика подключения..."
echo -e "${INFO} Статус контейнера:"
docker ps | grep nextcloud-aio || echo "Контейнер не найден"

echo -e "${INFO} Порты:"
netstat -tlnp | grep :8080 || echo "Порт 8080 не слушается"

echo -e "${INFO} Логи контейнера (последние 10 строк):"
docker logs --tail 10 nextcloud-aio 2>/dev/null || echo "Нет логов"

# Проверка статуса
if docker ps | grep -q nextcloud-aio; then
    echo -e "\n${CHECKMARK} ${GREEN}Nextcloud AIO запущен!${NC}\n"
    echo -e "${INFO} Попробуйте эти ссылки:"
    echo -e "${BLUE}https://$VPS_IP:8080${NC} (HTTPS - рекомендуется)"
    echo -e "${BLUE}http://$VPS_IP:8080${NC} (HTTP)"
    echo -e "\n${WARNING} Если не открывается:"
    echo -e "1. Проверьте firewall: ${YELLOW}ufw status${NC}"
    echo -e "2. Проверьте логи: ${YELLOW}docker logs nextcloud-aio${NC}"
    echo -e "3. Попробуйте перезапустить: ${YELLOW}docker restart nextcloud-aio${NC}"
else
    echo -e "\n${CROSS} ${RED}Контейнер не запущен${NC}"
    echo -e "${INFO} Логи ошибок:"
    docker logs nextcloud-aio
    exit 1
fi

echo -e "\n${CHECKMARK} ${GREEN}Установка завершена!${NC}"
