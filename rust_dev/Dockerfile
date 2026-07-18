FROM rust:latest

ADD script/. /tmp
ADD default_kconfig /tmp
RUN chmod +x /tmp/build.sh && /tmp/build.sh