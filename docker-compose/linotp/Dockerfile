FROM debian:buster

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    curl wget gnupg2 software-properties-common apt-transport-https lsb-release debconf-utils expect postgresql-client

RUN echo "deb http://dist.linotp.org/debian/linotp3 buster linotp" > /etc/apt/sources.list.d/linotp.list \
 && curl -fsSL https://dist.linotp.org/debian/gpg-keys/linotp-archive-current.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/linotp.gpg

RUN echo "linotp-webui linotp/apache/activate boolean true" | debconf-set-selections && \
    echo "linotp-webui linotp/apache/ssl_create boolean true" | debconf-set-selections && \
    echo "linotp-webui linotp/database/fix_encoding boolean false" | debconf-set-selections && \
    echo "linotp-webui linotp/create_admin_note boolean false" | debconf-set-selections && \
    echo "linotp-webui linotp/dbconfig-install boolean false" | debconf-set-selections && \
    apt update && apt install -y apache2 linotp linotp-archive-keyring python3-pip && \
    apt clean

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
