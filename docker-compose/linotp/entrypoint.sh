#!/bin/bash
set -e

echo "⌛ Ozhidanie dostupnosti PostgreSQL na ${DB_HOST}..."
until pg_isready -h "$DB_HOST" -p 5432 -U "$DB_USER"; do
  sleep 2
done
echo "✅ PostgreSQL dostupen."

mkdir -p /etc/linotp/conf.d
echo "DATABASE_URI = 'postgresql://${DB_USER}:${DB_PASS}@${DB_HOST}/${DB_NAME}'" > /etc/linotp/conf.d/10-database.cfg

mkdir -p /usr/lib/python3/dist-packages/linotp/cache
mkdir -p /usr/lib/python3/dist-packages/linotp/logs

linotp init database

if ! linotp local-admins list | grep -q "$ADMIN_USER"; then
    linotp local-admins add "$ADMIN_USER"
fi

expect <<EOF
spawn linotp local-admins password "$ADMIN_USER"
expect "Password:"
send "$ADMIN_PASS\r"
expect "Repeat for confirmation:"
send "$ADMIN_PASS\r"
expect eof
EOF

echo 'ServerName linotp.local' > /etc/apache2/conf-available/fqdn.conf
a2enconf fqdn

apachectl -D FOREGROUND
