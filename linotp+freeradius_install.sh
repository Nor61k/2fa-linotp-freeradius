#!/bin/bash

LOG_FILE="/var/log/linotp_radius_install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Полная установка LinOTP с PostgreSQL и FreeRADIUS ==="

# --- Проверка версии дистрибутива ---
DISTRO=$(lsb_release -cs)
if [[ "$DISTRO" != "buster" && "$DISTRO" != "bullseye" ]]; then
  echo "⚠️  Этот скрипт тестировался на Debian 10 (buster) и 11 (bullseye)."
  echo "❌ Обнаружена неподдерживаемая версия: $(lsb_release -ds)"
  exit 1
fi

# --- Ввод всех данных пользователя сразу ---
echo "[?] Ввод параметров установки"
read -p "PostgreSQL: имя пользователя: " DB_USER
read -s -p "PostgreSQL: пароль: " DB_PASS
echo
read -p "PostgreSQL: имя базы данных: " DB_NAME
read -p "PostgreSQL: IP адрес сервера БД [127.0.0.1]: " DB_HOST
DB_HOST=${DB_HOST:-127.0.0.1}

read -p "Имя администратора LinOTP: " ADMIN_USER
read -p "IP-адрес сервера LinOTP [127.0.0.1]: " LINOTP_IP
LINOTP_IP=${LINOTP_IP:-127.0.0.1}

read -p "Введите имя клиента RADIUS: " RADIUS_CLIENT_NAME
read -p "Введите IP-адрес клиента RADIUS: " RADIUS_CLIENT_IP
read -p "Введите shared secret для клиента RADIUS: " RADIUS_SECRET

read -p "Введите имя Realm для LinOTP: " REALM
read -p "Введите имя Resolver для LinOTP: " RESCONF

# --- Подготовка apt источников ---
echo "[+] Раскомментируем источники apt и отключим cdrom..."
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak && \
sudo awk '
/^[[:space:]]*deb cdrom:/ || /^[[:space:]]*# *deb cdrom:/ { print "#" $0; next }
/^# *deb / && $2 !~ /^cdrom:/ { sub(/^# */, ""); print; next }
{ print }
' /etc/apt/sources.list.bak > /tmp/sources.list && \
sudo mv /tmp/sources.list /etc/apt/sources.list

echo "[+] Добавляем нужные репозитории..."
echo "deb https://deb.debian.org/debian/ buster main contrib non-free" | sudo tee /etc/apt/sources.list.d/buster.list > /dev/null
echo "deb http://dist.linotp.org/debian/linotp3 buster linotp" | sudo tee /etc/apt/sources.list.d/linotp.list > /dev/null

echo "[+] Устанавливаем ключи..."
sudo apt install -y debian-archive-keyring curl
curl https://dist.linotp.org/debian/gpg-keys/linotp-archive-current.asc | sudo tee /etc/apt/trusted.gpg.d/linotp-archive-current.asc > /dev/null

# --- Обновление ---
echo "[+] Обновление apt..."
sudo apt update

# --- Установка PostgreSQL ---
echo "[+] Установка PostgreSQL..."
sudo apt install -y postgresql

# --- Создание PostgreSQL пользователя и БД ---
echo "[+] Создание пользователя и базы данных..."
cd /tmp || exit 1

sudo -u postgres psql <<EOF
DO \$\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = '${DB_USER}') THEN
      CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';
   END IF;
END
\$\$;
EOF

if sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then
    echo "[=] База данных '${DB_NAME}' уже существует, пропускаем создание."
else
    sudo -u postgres createdb -O "${DB_USER}" -E UTF8 "${DB_NAME}"
    echo "[+] База данных '${DB_NAME}' создана."
fi

# --- Подготовка параметров debconf для установки LinOTP ---
echo "[+] Предзаполнение debconf для установки LinOTP..."
echo "linotp-webui linotp/apache/activate boolean true" | sudo debconf-set-selections
echo "linotp-webui linotp/apache/ssl_create boolean true" | sudo debconf-set-selections
echo "linotp-webui linotp/database/fix_encoding boolean false" | sudo debconf-set-selections
echo "linotp-webui linotp/create_admin_note boolean false" | sudo debconf-set-selections
echo "linotp-webui linotp/dbconfig-install boolean false" | sudo debconf-set-selections

# --- Установка LinOTP ---
echo "[+] Установка LinOTP..."
sudo apt install -y linotp-archive-keyring linotp

# --- Настройка конфигурации LinOTP ---
CFG_FILE="/usr/share/linotp/linotp.cfg"
echo "[+] Настройка конфигурации LinOTP ($CFG_FILE)..."
sudo sed -i '/^DATABASE_URI/d' "$CFG_FILE" 2>/dev/null
DB_URI="postgresql://${DB_USER}:${DB_PASS}@${DB_HOST}/${DB_NAME}"
echo "DATABASE_URI = '${DB_URI}'" | sudo tee -a "$CFG_FILE" > /dev/null

# --- Инициализация БД LinOTP ---
echo "[+] Инициализация БД LinOTP..."
sudo linotp init database

# --- Перезапуск Apache ---
echo "[+] Перезапуск Apache..."
sudo systemctl restart apache2

# --- Создание администратора ---
echo "[+] Создание администратора LinOTP..."
sudo linotp local-admins add "$ADMIN_USER"
echo "[!] Установите пароль администратора вручную:"
sudo linotp local-admins password "$ADMIN_USER"

# --- Установка FreeRADIUS и зависимостей ---
echo "[+] Установка FreeRADIUS и зависимостей..."
sudo apt install -y python3-ldap freeradius python3-passlib python3-bcrypt git libtry-tiny-perl libio-all-lwp-perl libconfig-file-perl

# --- Символические ссылки FreeRADIUS ---
echo "[+] Создание симлинков FreeRADIUS..."
sudo ln -sf /etc/freeradius/3.0/sites-available /etc/freeradius/sites-available
sudo ln -sf /etc/freeradius/3.0/sites-enabled /etc/freeradius/sites-enabled
sudo ln -sf /etc/freeradius/3.0/clients.conf /etc/freeradius/clients.conf
sudo ln -sf /etc/freeradius/3.0/users /etc/freeradius/users

# --- Клонирование и установка модуля LinOTP для FreeRADIUS ---
echo "[+] Клонирование модуля LinOTP RADIUS Perl..."
sudo git clone https://github.com/LinOTP/linotp-auth-freeradius-perl.git /root/linotp-auth-freeradius-perl

sudo mkdir -p /usr/share/linotp
sudo cp /root/linotp-auth-freeradius-perl/radius_linotp.pm /usr/share/linotp/radius_linotp.pm

# --- Настройка виртуального сервера linotp ---
echo "[+] Конфигурация виртуального сервера linotp..."
cat <<EOF | sudo tee /etc/freeradius/3.0/sites-enabled/linotp > /dev/null
server linotp {
  listen {
    ipaddr = *
    port = 1812
    type = auth
  }
  listen {
    ipaddr = *
    port = 1813
    type = acct
  }
  authorize {
    preprocess
    update {
      &control:Auth-Type := Perl
    }
  }
  authenticate {
    Auth-Type Perl {
      perl
    }
  }
  accounting {
    unix
  }
}
EOF

# --- Очистка ненужных сайтов ---
echo "[+] Очистка лишних сайтов..."
sudo find /etc/freeradius/3.0/sites-enabled/ ! -name 'linotp' -type f -exec rm -f {} +
sudo find /etc/freeradius/sites-enabled/ ! -name 'linotp' -type f -exec rm -f {} +
sudo rm -f /etc/freeradius/sites-enabled/default
sudo rm -f /etc/freeradius/sites-enabled/inner-tunnel

# --- Настройка users и perl ---
echo "[+] Настройка FreeRADIUS users и Perl модуля..."
echo "DEFAULT Auth-Type := perl" | sudo tee /etc/freeradius/3.0/users > /dev/null

cat <<EOF | sudo tee /etc/freeradius/3.0/mods-available/perl > /dev/null
perl {
  filename = /usr/share/linotp/radius_linotp.pm
  func_authenticate = authenticate
  func_authorize = authorize
}
EOF

# --- Активация perl модуля и удаление eap ---
echo "[+] Удаление EAP из mods-enabled..."
sudo ln -sf /etc/freeradius/3.0/mods-available/perl /etc/freeradius/3.0/mods-enabled/perl
sudo rm -f /etc/freeradius/3.0/mods-enabled/eap

# --- Конфигурация rlm_perl.ini ---
echo "[+] Создание конфигурации LinOTP RADIUS..."
sudo mkdir -p /etc/linotp2
cat <<EOF | sudo tee /etc/linotp2/rlm_perl.ini > /dev/null
URL=http://${LINOTP_IP}/validate/simplecheck
REALM=${REALM}
RESCONF=${RESCONF}
Debug=True
SSL_CHECK=False
EOF

# --- Установка Perl-модуля Config::File ---
echo "[+] Установка Perl-модуля Config::File..."
echo "yes" | sudo cpan Config::File

# --- Настройка клиента RADIUS ---
echo "[+] Настройка RADIUS клиента..."
cat <<EOF | sudo tee -a /etc/freeradius/3.0/clients.conf > /dev/null
client ${RADIUS_CLIENT_NAME} {
  ipaddr = ${RADIUS_CLIENT_IP}
  secret = ${RADIUS_SECRET}
}
EOF

# --- Перезапуск и проверка статуса ---
echo "[+] Перезапуск FreeRADIUS..."
sudo systemctl restart freeradius
sleep 5
echo "[+] Статус службы FreeRADIUS:"
sudo systemctl status freeradius --no-pager

echo "✅ Установка завершена. LinOTP + FreeRADIUS настроены. Лог: $LOG_FILE"

# --- Проверка на ошибки в логе ---
ERROR_LOG="/var/log/linotp_radius_install_errors.log"
grep -iE 'fail|error|не удалось|ошибка' "$LOG_FILE" | grep -vE 'liberror-perl|Enabling conf|Setting up' > "$ERROR_LOG"

if [[ -s "$ERROR_LOG" ]]; then
  echo "❗ Внимание: Обнаружены возможные ошибки в процессе установки."
  echo "Просмотрите файл ошибок: $ERROR_LOG"
else
  echo "🟢 Установка прошла без критических ошибок."
  rm -f "$ERROR_LOG"
fi

