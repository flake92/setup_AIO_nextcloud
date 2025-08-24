#!/bin/bash

# Тестовый скрипт для проверки функциональности nextcloud-aio.sh
# Проверяет основные функции без реального запуска установки

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_PATH="./nextcloud-aio.sh"
TEST_LOG="/tmp/nextcloud-aio-test.log"

echo -e "${BLUE}🧪 Запуск тестов для nextcloud-aio.sh${NC}\n"

# Проверка существования скрипта
test_file_exists() {
    echo -n "Проверка существования скрипта... "
    if [ -f "$SCRIPT_PATH" ]; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗ Файл не найден${NC}"
        return 1
    fi
}

# Проверка синтаксиса bash
test_bash_syntax() {
    echo -n "Проверка синтаксиса bash... "
    if bash -n "$SCRIPT_PATH" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗ Ошибки синтаксиса${NC}"
        bash -n "$SCRIPT_PATH"
        return 1
    fi
}

# Проверка shellcheck (если доступен)
test_shellcheck() {
    echo -n "Проверка shellcheck... "
    if command -v shellcheck >/dev/null 2>&1; then
        local warnings=$(shellcheck "$SCRIPT_PATH" 2>&1 | grep -c "warning" || true)
        local errors=$(shellcheck "$SCRIPT_PATH" 2>&1 | grep -c "error" || true)
        
        if [ "$errors" -eq 0 ]; then
            if [ "$warnings" -eq 0 ]; then
                echo -e "${GREEN}✓ Без предупреждений${NC}"
            else
                echo -e "${YELLOW}⚠ $warnings предупреждений${NC}"
            fi
            return 0
        else
            echo -e "${RED}✗ $errors ошибок${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠ shellcheck не установлен${NC}"
        return 0
    fi
}

# Проверка функций определения ОС
test_os_detection() {
    echo -n "Проверка функций определения ОС... "
    
    if grep -q "detect_os()" "$SCRIPT_PATH" || grep -q "detect_os " "$SCRIPT_PATH"; then
        echo -e "${GREEN}✓ Функция найдена${NC}"
        return 0
    else
        echo -e "${RED}✗ Функция detect_os не найдена${NC}"
        return 1
    fi
}

# Проверка функций статуса
test_status_functions() {
    echo -n "Проверка функций статуса... "
    
    local functions=("get_container_status" "get_install_status" "get_install_progress")
    local found=0
    
    for func in "${functions[@]}"; do
        if grep -q "${func}()" "$SCRIPT_PATH"; then
            ((found++))
        fi
    done
    
    if [ "$found" -eq 3 ]; then
        echo -e "${GREEN}✓ Все функции найдены${NC}"
        return 0
    else
        echo -e "${RED}✗ Найдено $found из 3 функций${NC}"
        return 1
    fi
}

# Проверка переменных окружения
test_environment_variables() {
    echo -n "Проверка переменных окружения... "
    
    local vars=("SCREEN_SESSION" "CONTAINER_NAME" "INSTALL_LOG" "PID_FILE")
    local found=0
    
    for var in "${vars[@]}"; do
        if grep -q "$var=" "$SCRIPT_PATH"; then
            ((found++))
        fi
    done
    
    if [ "$found" -eq 4 ]; then
        echo -e "${GREEN}✓ Все переменные найдены${NC}"
        return 0
    else
        echo -e "${RED}✗ Найдено $found из 4 переменных${NC}"
        return 1
    fi
}

# Проверка функций меню
test_menu_functions() {
    echo -n "Проверка функций меню... "
    
    local functions=("print_banner" "print_menu" "print_status_box")
    local found=0
    
    for func in "${functions[@]}"; do
        if grep -q "${func}()" "$SCRIPT_PATH"; then
            ((found++))
        fi
    done
    
    if [ "$found" -eq 3 ]; then
        echo -e "${GREEN}✓ Все функции меню найдены${NC}"
        return 0
    else
        echo -e "${RED}✗ Найдено $found из 3 функций меню${NC}"
        return 1
    fi
}

# Проверка функций установки Docker
test_docker_functions() {
    echo -n "Проверка функций Docker... "
    
    if grep -q "get.docker.com" "$SCRIPT_PATH"; then
        echo -e "${GREEN}✓ Использует официальный установщик Docker${NC}"
        return 0
    else
        echo -e "${RED}✗ Официальный установщик Docker не найден${NC}"
        return 1
    fi
}

# Проверка обработки ошибок
test_error_handling() {
    echo -n "Проверка обработки ошибок... "
    
    local error_patterns=("exit 1" "return 1" "|| exit" "|| return")
    local found=0
    
    for pattern in "${error_patterns[@]}"; do
        if grep -q "$pattern" "$SCRIPT_PATH"; then
            ((found++))
        fi
    done
    
    if [ "$found" -gt 0 ]; then
        echo -e "${GREEN}✓ Обработка ошибок присутствует${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Минимальная обработка ошибок${NC}"
        return 0
    fi
}

# Проверка безопасности
test_security() {
    echo -n "Проверка безопасности... "
    
    local issues=0
    
    # Проверка на hardcoded пароли
    if grep -i "password.*=" "$SCRIPT_PATH" | grep -v "read" | grep -q "="; then
        echo -e "${RED}✗ Возможны hardcoded пароли${NC}"
        ((issues++))
    fi
    
    # Проверка на eval
    if grep -q "eval" "$SCRIPT_PATH"; then
        echo -e "${RED}✗ Использование eval небезопасно${NC}"
        ((issues++))
    fi
    
    # Проверка на curl без проверки SSL
    if grep -q "curl.*-k\|curl.*--insecure" "$SCRIPT_PATH"; then
        echo -e "${RED}✗ Curl без проверки SSL${NC}"
        ((issues++))
    fi
    
    if [ "$issues" -eq 0 ]; then
        echo -e "${GREEN}✓ Основные проблемы безопасности не найдены${NC}"
        return 0
    else
        echo -e "${RED}✗ Найдено $issues проблем безопасности${NC}"
        return 1
    fi
}

# Проверка совместимости с различными дистрибутивами
test_distro_compatibility() {
    echo -n "Проверка совместимости с дистрибутивами... "
    
    local package_managers=("apt" "dnf" "yum" "pacman" "zypper")
    local found=0
    
    for pm in "${package_managers[@]}"; do
        if grep -q "$pm" "$SCRIPT_PATH"; then
            ((found++))
        fi
    done
    
    if [ "$found" -ge 4 ]; then
        echo -e "${GREEN}✓ Поддержка множественных дистрибутивов${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Ограниченная поддержка дистрибутивов${NC}"
        return 0
    fi
}

# Основная функция тестирования
run_tests() {
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    
    echo -e "${BLUE}Запуск тестов...${NC}\n"
    
    # Список всех тестов
    local tests=(
        "test_file_exists"
        "test_bash_syntax" 
        "test_shellcheck"
        "test_os_detection"
        "test_status_functions"
        "test_environment_variables"
        "test_menu_functions"
        "test_docker_functions"
        "test_error_handling"
        "test_security"
        "test_distro_compatibility"
    )
    
    for test in "${tests[@]}"; do
        ((total_tests++))
        if $test; then
            ((passed_tests++))
        else
            ((failed_tests++))
        fi
    done
    
    echo -e "\n${BLUE}Результаты тестирования:${NC}"
    echo -e "Всего тестов: $total_tests"
    echo -e "${GREEN}Пройдено: $passed_tests${NC}"
    echo -e "${RED}Провалено: $failed_tests${NC}"
    
    if [ "$failed_tests" -eq 0 ]; then
        echo -e "\n${GREEN}🎉 Все тесты пройдены успешно!${NC}"
        return 0
    else
        echo -e "\n${YELLOW}⚠ Некоторые тесты провалены. Проверьте детали выше.${NC}"
        return 1
    fi
}

# Запуск тестов
run_tests

echo -e "\n${BLUE}Тестирование завершено.${NC}"
