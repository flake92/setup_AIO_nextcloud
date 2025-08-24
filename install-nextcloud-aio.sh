#!/bin/bash

# 🚀 Nextcloud AIO - Простая установка для Debian 12
# Устанавливает Docker, обновляет систему и запускает Nextcloud All-in-One

set -euo pipefail

# 🎨 Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 📋 Проверка root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Запустите от root: sudo $0${NC}"
    exit 1
fi

echo -e "${BLUE}🚀 Установка Nextcloud AIO на Debian 12${NC}"
echo

# 🔄 Обновление системы
echo -e "${BLUE}📦 Обновление системы...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq curl wget ca-certificates gnupg lsb-release
echo -e "${GREEN}✅ Система обновлена${NC}"

# 🐳 Установка Docker
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

# 🌐 Получаем IP
echo -e "${BLUE}🌐 Определение IP адреса...${NC}"
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "localhost")
echo -e "${GREEN}✅ IP: $SERVER_IP${NC}"

# 🚀 Запуск Nextcloud AIO
echo -e "${BLUE}🚀 Запуск Nextcloud AIO...${NC}"

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
    ghcr.io/nextcloud/all-in-one:latest

# Проверяем запуск
sleep 5
if docker ps | grep -q nextcloud-aio-mastercontainer; then
    echo -e "${GREEN}✅ Nextcloud AIO запущен успешно!${NC}"
else
    echo -e "${RED}❌ Ошибка запуска${NC}"
    docker logs nextcloud-aio-mastercontainer 2>/dev/null || true
    exit 1
fi

# 📋 Информация для доступа
echo
echo -e "${GREEN}🎉 УСТАНОВКА ЗАВЕРШЕНА!${NC}"
echo
echo -e "${BLUE}📋 Доступ к Nextcloud AIO:${NC}"
echo -e "   🌐 HTTP:  ${YELLOW}http://$SERVER_IP:8080${NC}"
echo -e "   🔒 HTTPS: ${YELLOW}https://$SERVER_IP:8443${NC}"
echo
echo -e "${BLUE}🔧 Управление:${NC}"
echo -e "   📊 Статус:     ${GREEN}docker ps${NC}"
echo -e "   📝 Логи:       ${GREEN}docker logs nextcloud-aio-mastercontainer${NC}"
echo -e "   🔄 Перезапуск: ${GREEN}docker restart nextcloud-aio-mastercontainer${NC}"
echo
echo -e "${GREEN}✨ Откройте браузер и перейдите по ссылке выше!${NC}"
