# LinOTP + FreeRADIUS + PostgreSQL: 2FA-сервер с RADIUS-интерфейсом

## 📌 Описание

Этот проект разворачивает полностью готовое к использованию решение двухфакторной аутентификации (2FA) с использованием:

- **LinOTP** — централизованный сервер токенов и аутентификации
- **FreeRADIUS** — интерфейс RADIUS для взаимодействия с VPN, firewalls и др.
- **PostgreSQL** — хранилище конфигурации и данных LinOTP
- Поддержка клиента, например: **Check Point NGFW**, **OpenVPN**, **FortiGate** и др.

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

---

## 🐳 Проект на Docker

Проект включает:
- `docker-compose.yml`
- `linotp/` — Dockerfile, скрипт запуска и настройки
- `freeradius/` — Dockerfile, конфиги, Perl-модуль `radius_linotp.pm`

### 🚀 Запуск:

```bash
docker compose up --build -d
```

### ⚠️ Перед запуском проверь:
Файл `docker-compose.yml`, секция `linotp.environment`:

```yaml
environment:
  DB_USER: linotp
  DB_PASS: adminpass
  DB_NAME: linotpdb
  DB_HOST: postgres
  ADMIN_USER: admin
  ADMIN_PASS: adminpass
```

### 🛠️ Что настраивается автоматически:
- RADIUS клиент (`clients.conf`)
- связка FreeRADIUS ↔ LinOTP через Perl
- PostgreSQL и база данных
- Создаётся администратор LinOTP
- Apache на порту 443

### 🧾 Подробнее в:
- [`CONFIG_GUIDE.md`](CONFIG_GUIDE.md)
- [`linotp-architecture.drawio`](linotp-architecture.drawio) — схема потоков

---

## 📄 Лицензия

Проект распространяется под лицензией **GNU Affero General Public License v3.0**  
См. файл [`LICENSE`](LICENSE)
