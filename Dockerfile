# vim:set ft=dockerfile:
FROM debian:buster-slim

ENV HAPROXY_VERSION v2.1-plus0
ENV HAPROXY_URL https://github.com/Azure/haproxy/tarball/v2.1-plus0
ENV HAPROXY_SHA256 9337167be4b2f991208550c555eac67ab3390da4fe04e49c95aae10d5c9dd0b3

# see https://sources.debian.net/src/haproxy/jessie/debian/rules/ for some helpful navigation of the possible "make" arguments
RUN set -x \
	\
	&& savedAptMark="$(apt-mark showmanual)" \
	&& apt-get update && apt-get install -y --no-install-recommends \
		ca-certificates \
		gcc \
      iproute2 \
		libc6-dev \
		liblua5.3-dev \
		libpcre2-dev \
		libssl-dev \
		make \
		wget \
		zlib1g-dev

COPY . /usr/haproy/src

RUN makeOpts=' \
		TARGET=linux-glibc \
		USE_GETADDRINFO=1 \
		USE_LUA=1 LUA_INC=/usr/include/lua5.3 \
		USE_OPENSSL=1 \
		USE_PCRE2=1 USE_PCRE2_JIT=1 \
		USE_ZLIB=1 \
		\
		EXTRA_OBJS="contrib/prometheus-exporter/service-prometheus.o" \
	' \
	&& nproc="$(nproc)" \
	&& eval "make -C /usr/src/haproxy -j '$nproc' all $makeOpts" \
	&& eval "make -C /usr/src/haproxy install-bin $makeOpts" \
	\
	&& mkdir -p /usr/local/etc/haproxy \
	&& cp -R /usr/src/haproxy/examples/errorfiles /usr/local/etc/haproxy/errors

# https://www.haproxy.org/download/1.8/doc/management.txt
# "4. Stopping and restarting HAProxy"
# "when the SIGTERM signal is sent to the haproxy process, it immediately quits and all established connections are closed"
# "graceful stop is triggered when the SIGUSR1 signal is sent to the haproxy process"
STOPSIGNAL SIGUSR1

COPY docker-entrypoint.sh /
RUN chmod 755 /docker-entrypoint.sh

RUN useradd -rs /bin/bash haproxy
RUN setcap 'cap_net_bind_service=+ep' /usr/local/sbin/haproxy
# this is where the haproxy.sock and haproxy.pid reside
RUN mkdir /run/haproxy
RUN chown -R haproxy:haproxy /run/haproxy

USER haproxy
EXPOSE 443
EXPOSE 8080


ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg"]
