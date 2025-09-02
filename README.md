# Nextcloud AIO - Простая установка

Автоматическая установка Nextcloud All-in-One на Debian 12 с Docker.

## 🚀 Установка

```bash
apt update -y && apt install sudo -y
wget https://raw.githubusercontent.com/flake92/setup_AIO_nextcloud/main/install-nextcloud-aio.sh
chmod +x install-nextcloud-aio.sh
sudo ./install-nextcloud-aio.sh
```

## 📋 Что делает скрипт

1. ✅ Обновляет Debian 12
2. 🐳 Устанавливает Docker из официального репозитория
3. 🚀 Запускает Nextcloud AIO контейнер
4. 🌐 Показывает ссылки для доступа

## 🧰 Возможности скрипта

- **Интерактивное меню** с удобными опциями установки и обслуживания
- **Обновление системы** с установкой базовых утилит (curl, htop, screen и т.д.)
- **Базовая безопасность**: настройка UFW и Fail2ban для защиты SSH
- **Установка Docker** из официального репозитория Docker
- **Автозапуск Nextcloud AIO** с публикацией портов 80/443/8080/8443
- **Подсказки по дальнейшим шагам** и полезные команды после установки
- **Запуск в screen** и **проверка статуса** установки

## 🧭 Опции меню

1. **Полная установка (рекомендуется)** — обновление системы, Docker, запуск AIO
2. **Только обновить систему** — апдейты + UFW/Fail2ban
3. **Только установить Docker** — установка и запуск сервиса
4. **Только запустить Nextcloud AIO** — перезапуск/запуск мастер-контейнера
5. **Запустить в screen сессии** — фоновый запуск полного инсталла
6. **Проверить статус установки** — Docker, контейнеры, порты, UFW
0. **Выход**

Альтернатива без меню:

```bash
sudo ./install-nextcloud-aio.sh --full-install
```

## 🔐 Открываемые порты и файрвол (UFW)

Скрипт настраивает UFW и открывает порты:

- 22/tcp (SSH)
- 80/tcp (HTTP)
- 443/tcp (HTTPS)
- 8080/tcp (AIO HTTP интерфейс)
- 8443/tcp (AIO HTTPS интерфейс)
- 3478/tcp и 3478/udp, 10000-20000/udp (Nextcloud Talk)

UFW включается автоматически. Статус: `ufw status numbered`.

## 🖥️ Запуск в screen

Выберите пункт меню 5 или выполните:

```bash
screen -dmS nextcloud-install bash -c "./install-nextcloud-aio.sh --full-install; exec bash"
```

Подключиться: `screen -r nextcloud-install`.
Отключиться: `Ctrl+A`, затем `D`.

## 📊 Проверка статуса

Пункт меню 6 показывает:

- Наличие и статус Docker
- Запущен ли `nextcloud-aio-mastercontainer`
- Ссылки для доступа по IP
- Список контейнеров AIO и их состояние
- Открытость портов 80/443/8080/8443/3478
- Статус UFW

## 🌐 Доступ

После установки:

- **HTTP**: `http://ваш-ip:8080`
- **HTTPS**: `https://ваш-ip:8443` (рекомендуется)

При первом входе подтвердите предупреждение о сертификате и создайте админа Nextcloud.

## 💡 Советы после установки

- На слабом VPS отключите ресурсоёмкие приложения (OnlyOffice, Talk, Whiteboard)
- Смените пароль root: `passwd`
- Настройте вход по SSH-ключам вместо пароля

## 🧩 Устранение неполадок

- Проверить контейнеры: `docker ps -a`
- Перезапустить мастер-контейнер: `docker restart nextcloud-aio-mastercontainer`
- Логи: `docker logs -f nextcloud-aio-mastercontainer`
- Проверить порты: `netstat -tulpn | grep -E ':(80|443|8080|8443)'`

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
