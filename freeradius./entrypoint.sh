#!/bin/bash
set -e

if [ -d /etc/freeradius/sites-enabled ]; then
  find /etc/freeradius/sites-enabled/ -type l ! -name 'linotp' -exec rm -f {} +
fi

rm -f /etc/freeradius/3.0/mods-enabled/files
rm -f /etc/freeradius/3.0/mods-enabled/eap
rm -f /etc/freeradius/3.0/sites-enabled/default
rm -f /etc/freeradius/3.0/sites-enabled/inner-tunnel

mkdir -p /usr/share/linotp
cp /entrypoint.d/radius_linotp.pm /usr/share/linotp/radius_linotp.pm

cat <<EOF > /etc/freeradius/3.0/clients.conf
client ${RADIUS_CLIENT_NAME} {
  ipaddr = ${RADIUS_CLIENT_IP}
  secret = ${RADIUS_SECRET}
}
EOF

cat <<EOF > /etc/freeradius/3.0/mods-available/perl
perl {
  filename = /usr/share/linotp/radius_linotp.pm
  func_authenticate = authenticate
  func_authorize = authorize
}
EOF

ln -sf /etc/freeradius/3.0/mods-available/perl /etc/freeradius/3.0/mods-enabled/perl
echo "DEFAULT Auth-Type := perl" > /etc/freeradius/3.0/users

mkdir -p /etc/linotp2
cat <<EOF > /etc/linotp2/rlm_perl.ini
URL=${LINOTP_URL}
REALM=realm1
RESCONF=resolver1
Debug=True
SSL_CHECK=False
EOF

cat <<EOF > /etc/freeradius/3.0/sites-enabled/linotp
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

freeradius -X
