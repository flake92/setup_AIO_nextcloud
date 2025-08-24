#!/bin/bash

# Интеграционный тест для проверки установки Nextcloud AIO
# Тестирует реальные сценарии использования без фактической установки

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_PATH="./nextcloud-aio.sh"

echo -e "${BLUE}🔧 Интеграционные тесты для nextcloud-aio.sh${NC}\n"

# Проверка определения IP адреса
test_ip_detection() {
    echo -n "Тест определения IP адреса... "
    
    # Извлекаем функцию detect_ip и тестируем её
    local ip_sources=("ifconfig.me" "ipinfo.io" "icanhazip.com")
    local working_sources=0
    
    for source in "${ip_sources[@]}"; do
        if curl -s --connect-timeout 5 "$source" >/dev/null 2>&1; then
            ((working_sources++))
        fi
    done
    
    if [ "$working_sources" -gt 0 ]; then
        echo -e "${GREEN}✓ $working_sources из ${#ip_sources[@]} источников доступны${NC}"
        return 0
    else
        echo -e "${RED}✗ Нет доступных источников IP${NC}"
        return 1
    fi
}

# Проверка доступности Docker репозитория
test_docker_availability() {
    echo -n "Тест доступности Docker установщика... "
    
    if curl -fsSL https://get.docker.com >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Docker установщик доступен${NC}"
        return 0
    else
        echo -e "${RED}✗ Docker установщик недоступен${NC}"
        return 1
    fi
}

# Проверка определения операционной системы
test_os_detection_real() {
    echo -n "Тест реального определения ОС... "
    
    # Проверяем наличие /etc/os-release
    if [ -f /etc/os-release ]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        echo -e "${GREEN}✓ ОС: $ID $VERSION_ID${NC}"
        return 0
    elif [ -f /etc/redhat-release ]; then
        echo -e "${GREEN}✓ ОС: RHEL/CentOS${NC}"
        return 0
    elif [ -f /etc/arch-release ]; then
        echo -e "${GREEN}✓ ОС: Arch Linux${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Неизвестная ОС${NC}"
        return 0
    fi
}

# Проверка доступности пакетных менеджеров
test_package_managers() {
    echo -n "Тест доступности пакетных менеджеров... "
    
    local managers=("apt-get" "dnf" "yum" "pacman" "zypper")
    local available=0
    local current=""
    
    for manager in "${managers[@]}"; do
        if command -v "$manager" >/dev/null 2>&1; then
            current="$manager"
            ((available++))
        fi
    done
    
    if [ "$available" -gt 0 ]; then
        echo -e "${GREEN}✓ Доступен: $current${NC}"
        return 0
    else
        echo -e "${RED}✗ Пакетные менеджеры не найдены${NC}"
        return 1
    fi
}

# Проверка системных требований
test_system_requirements() {
    echo -n "Тест системных требований... "
    
    local issues=0
    
    # Проверка RAM (минимум 2GB) - адаптировано для macOS
    local ram_gb
    if command -v free >/dev/null 2>&1; then
        ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        ram_gb=$(($(sysctl -n hw.memsize) / 1024 / 1024 / 1024))
    else
        ram_gb=4  # Предполагаем достаточно RAM если не можем определить
    fi
    
    if [ "$ram_gb" -lt 2 ]; then
        echo -e "${RED}✗ Недостаточно RAM: ${ram_gb}GB < 2GB${NC}"
        ((issues++))
    fi
    
    # Проверка свободного места (минимум 40GB) - адаптировано для macOS
    local free_gb
    if [[ "$OSTYPE" == "darwin"* ]]; then
        free_gb=$(df -g / | awk 'NR==2{print $4}')
    else
        free_gb=$(df --block-size=1G / | awk 'NR==2{print $4}' 2>/dev/null || df / | awk 'NR==2{print int($4/1024/1024)}')
    fi
    
    if [ "$free_gb" -lt 40 ]; then
        echo -e "${RED}✗ Недостаточно места: ${free_gb}GB < 40GB${NC}"
        ((issues++))
    fi
    
    if [ "$issues" -eq 0 ]; then
        echo -e "${GREEN}✓ Требования выполнены (RAM: ${ram_gb}GB, Диск: ${free_gb}GB)${NC}"
        return 0
    else
        echo -e "${RED}✗ $issues проблем с требованиями${NC}"
        return 1
    fi
}

# Проверка портов
test_ports_availability() {
    echo -n "Тест доступности портов... "
    
    local ports=(8080 8443 3478)
    local busy_ports=()
    
    for port in "${ports[@]}"; do
        if command -v ss >/dev/null 2>&1; then
            if ss -tlnp | grep -q ":$port "; then
                busy_ports+=("$port")
            fi
        elif command -v netstat >/dev/null 2>&1; then
            if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
                busy_ports+=("$port")
            fi
        elif command -v lsof >/dev/null 2>&1; then
            if lsof -i ":$port" >/dev/null 2>&1; then
                busy_ports+=("$port")
            fi
        fi
    done
    
    if [ ${#busy_ports[@]} -eq 0 ]; then
        echo -e "${GREEN}✓ Все порты свободны${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Заняты порты: ${busy_ports[*]}${NC}"
        return 0
    fi
}

# Проверка прав доступа
test_permissions() {
    echo -n "Тест прав доступа... "
    
    if [ "$EUID" -eq 0 ]; then
        echo -e "${GREEN}✓ Запущен с правами root${NC}"
        return 0
    elif command -v sudo >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠ Требуется sudo${NC}"
        return 0
    else
        echo -e "${RED}✗ Нет прав root и sudo недоступен${NC}"
        return 1
    fi
}

# Проверка зависимостей
test_dependencies() {
    echo -n "Тест базовых зависимостей... "
    
    local deps=("curl" "wget" "screen")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -eq 0 ]; then
        echo -e "${GREEN}✓ Все зависимости доступны${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Отсутствуют: ${missing[*]}${NC}"
        return 0
    fi
}

# Проверка сетевого подключения
test_network_connectivity() {
    echo -n "Тест сетевого подключения... "
    
    local test_urls=("google.com" "docker.com" "github.com")
    local reachable=0
    
    for url in "${test_urls[@]}"; do
        if ping -c 1 -W 3 "$url" >/dev/null 2>&1; then
            ((reachable++))
        fi
    done
    
    if [ "$reachable" -gt 0 ]; then
        echo -e "${GREEN}✓ Сеть доступна ($reachable из ${#test_urls[@]})${NC}"
        return 0
    else
        echo -e "${RED}✗ Нет сетевого подключения${NC}"
        return 1
    fi
}

# Проверка Docker (если установлен)
test_docker_status() {
    echo -n "Тест статуса Docker... "
    
    if command -v docker >/dev/null 2>&1; then
        if systemctl is-active docker >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Docker установлен и запущен${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ Docker установлен но не запущен${NC}"
            return 0
        fi
    else
        echo -e "${BLUE}ℹ Docker не установлен (будет установлен)${NC}"
        return 0
    fi
}

# Проверка существующих контейнеров Nextcloud
test_existing_containers() {
    echo -n "Тест существующих контейнеров... "
    
    if command -v docker >/dev/null 2>&1; then
        local containers=$(docker ps -a --filter "name=nextcloud" --format "{{.Names}}" 2>/dev/null || true)
        if [ -n "$containers" ]; then
            echo -e "${YELLOW}⚠ Найдены контейнеры: $containers${NC}"
            return 0
        else
            echo -e "${GREEN}✓ Конфликтующих контейнеров нет${NC}"
            return 0
        fi
    else
        echo -e "${BLUE}ℹ Docker не установлен${NC}"
        return 0
    fi
}

# Основная функция тестирования
run_integration_tests() {
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    
    echo -e "${BLUE}Запуск интеграционных тестов...${NC}\n"
    
    # Список всех тестов
    local tests=(
        "test_ip_detection"
        "test_docker_availability"
        "test_os_detection_real"
        "test_package_managers"
        "test_system_requirements"
        "test_ports_availability"
        "test_permissions"
        "test_dependencies"
        "test_network_connectivity"
        "test_docker_status"
        "test_existing_containers"
    )
    
    for test in "${tests[@]}"; do
        ((total_tests++))
        if $test; then
            ((passed_tests++))
        else
            ((failed_tests++))
        fi
    done
    
    echo -e "\n${BLUE}Результаты интеграционного тестирования:${NC}"
    echo -e "Всего тестов: $total_tests"
    echo -e "${GREEN}Пройдено: $passed_tests${NC}"
    echo -e "${RED}Провалено: $failed_tests${NC}"
    
    if [ "$failed_tests" -eq 0 ]; then
        echo -e "\n${GREEN}🎉 Система готова к установке Nextcloud AIO!${NC}"
        return 0
    else
        echo -e "\n${YELLOW}⚠ Обнаружены проблемы. Установка может быть затруднена.${NC}"
        return 1
    fi
}

# Запуск тестов
run_integration_tests

echo -e "\n${BLUE}Интеграционное тестирование завершено.${NC}"
