# Nextcloud AIO - IP-Based Installation

> **Официальный установщик Nextcloud AIO с доступом только по IP адресу**

## 🎯 Особенности

- ✅ **Строго по официальному мануалу** - https://github.com/nextcloud/all-in-one
- 🌐 **Автоопределение IP VPS** - показывает ссылки с IP адресом
- 📝 **Простая установка** - один скрипт, все автоматически

## ⚡ Быстрый старт

```bash
# Скачать скрипт
wget https://raw.githubusercontent.com/flake92/setup_AIO_nextcloud/main/install-nextcloud-aio.sh

# Сделать исполняемым
chmod +x install-nextcloud-aio.sh

# Запустить
sudo ./install-nextcloud-aio.sh
```

## 🌐 Доступ после установки

- **AIO Панель**: `http://ВАШ_IP:8080`
- **Nextcloud**: `http://ВАШ_IP:8443` (после настройки)

## 📋 Что делает скрипт

1. Определяет IP адрес VPS
2. Проверяет системные требования
3. Устанавливает Docker
4. Запускает официальный контейнер Nextcloud AIO
5. Показывает ссылки для доступа по IP

## 🔧 Системные требования

- **OS**: Debian/Ubuntu
- **RAM**: 2GB+
- **Диск**: 40GB+
- **Права**: sudo/root

## 📝 Следующие шаги

1. Откройте `http://ВАШ_IP:8080`
2. Настройте папку бэкапа
3. Выберите контейнеры
4. Нажмите "Start containers"

---

**Основано на**: https://github.com/nextcloud/all-in-one
