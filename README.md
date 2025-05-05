# LinOTP + FreeRADIUS + PostgreSQL: 2FA-сервер с RADIUS-интерфейсом

## 📌 Описание

Этот проект разворачивает полностью готовое к использованию решение двухфакторной аутентификации (2FA) с использованием:

- **LinOTP** — централизованный сервер токенов и аутентификации
- **FreeRADIUS** — интерфейс RADIUS для взаимодействия с VPN, firewalls и др.
- **PostgreSQL** — хранилище конфигурации и данных LinOTP
- Поддержка клиента по протоколу radius, например: **Check Point NGFW**, **OpenVPN**, **FortiGate** и др.

Поддерживается интеграция с LDAP, токены HOTP/TOTP, логирование, REST API.

---

## ⚙️ Скрипт автоматической установки (альтернатива Docker)

Файл: `linotp+freeradius_install.sh`  
Назначение: автоматическая установка LinOTP + FreeRADIUS + PostgreSQL на **Debian 10/11**.

### 🔄 Что делает скрипт:
- Проверяет ОС
- Запрашивает данные PostgreSQL, LinOTP admin, IP клиента RADIUS
- Устанавливает нужные пакеты
- Настраивает:
  - PostgreSQL: создаёт пользователя и базу
  - LinOTP: конфигурацию подключения к БД, админ аккаунт
  - FreeRADIUS: включает Perl-модуль, настраивает клиента и LinOTP как backend

### 🧪 Требования:
- Debian 10 или 11
- root-доступ
- Выход в интернет
- Порты 1812/1813/443 должны быть свободны

### ▶️ Запуск:

```bash
chmod +x install_linotp_radius.sh
./install_linotp_radius.sh
```

Скрипт запросит:
- логин/пароль от PostgreSQL
- имя базы
- IP LinOTP и клиента
- имя администратора
- shared secret
- realm
- resolver

---

## 🐳 Проект на Docker

Проект включает:
- `docker-compose.yml`
- `linotp/` — Dockerfile, скрипт запуска и настройки
- `freeradius/` — Dockerfile, конфиги, Perl-модуль `radius_linotp.pm`
- '.env' - Переменные

### 🚀 Запуск:
Перейти в папку docker-compose , там где находится файл docker-compose.yml
```bash
docker compose up --build -d
```

### ⚠️ Перед запуском проверь:
Файл `.env`:

```yaml
# Database
DB_USER=linotp
DB_PASS=yourpassword
DB_NAME=linotpdb
DB_HOST=postgres

# LinOTP Admin
ADMIN_USER=admin
ADMIN_PASS=adminpass

# RADIUS
RADIUS_CLIENT_NAME=myclient
RADIUS_CLIENT_IP=192.168.1.1
RADIUS_SECRET=mysecret
LINOTP_URL=https://linotp_app/validate/simplecheck

# RADIUS-LinOTP Plugin
REALM=realm1
RESCONF=resolver1

```

### 🛠️ Что настраивается автоматически:
- RADIUS клиент (`clients.conf`)
- связка FreeRADIUS ↔ LinOTP через Perl  
- PostgreSQL и база данных (указывайте логин , пароль , имя БД)
- Создаётся администратор LinOTP (указывайте логин и пароль)
- Apache на порту 443

На какие файлы стоит обращать внимание при дебаге:
- /etc/linotp2/rlm_perl.ini - конфиг для скрипта freeradius , тут указывается адрес linotp, имя realm и resolver  ,с которым freeradius обратится к linotp(не забываем синхронизировать эти настройки)
- /etc/freeradius/3.0/clients.conf - конфиг клиентов, на запросы с каких адресов отвечать и secret для radius

## 📄 Лицензия

Проект распространяется под лицензией **GNU Affero General Public License v3.0**  
См. файл [`LICENSE`](LICENSE)
