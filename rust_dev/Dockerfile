FROM ubuntu:25.04

ADD script/. /tmp
ADD default_kconfig /tmp
RUN chmod +x /tmp/build.sh && /tmp/build.sh