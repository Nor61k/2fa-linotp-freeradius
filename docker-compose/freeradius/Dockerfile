FROM debian:bullseye

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    freeradius git perl cpanminus \
    python3-ldap python3-passlib python3-bcrypt \
    libtry-tiny-perl libio-all-lwp-perl libconfig-file-perl && \
    apt clean

RUN cpanm Config::File

COPY entrypoint.sh /entrypoint.sh
COPY radius_linotp.pm /entrypoint.d/radius_linotp.pm
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
