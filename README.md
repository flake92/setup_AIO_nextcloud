# Nextcloud AIO - Простая установка

Автоматическая установка Nextcloud All-in-One на Debian 12 с Docker.

## 🚀 Установка

```bash
wget https://raw.githubusercontent.com/flake92/setup_AIO_nextcloud/main/install-nextcloud-aio.sh
chmod +x install-nextcloud-aio.sh
sudo ./install-nextcloud-aio.sh
```

## 📋 Что делает скрипт

1. ✅ Обновляет Debian 12
2. 🐳 Устанавливает Docker из официального репозитория
3. 🚀 Запускает Nextcloud AIO контейнер
4. 🌐 Показывает ссылки для доступа

## 🌐 Доступ

После установки:
- **HTTP**: `http://ваш-ip:8080`
- **HTTPS**: `https://ваш-ip:8443`

## 🛠️ Управление

```bash
# Статус
docker ps

# Логи
docker logs nextcloud-aio-mastercontainer

# Перезапуск
docker restart nextcloud-aio-mastercontainer
```

## 📚 Документация

- [Nextcloud AIO](https://github.com/nextcloud/all-in-one)

---

Простой скрипт без лишнего кода. Работает из коробки.
