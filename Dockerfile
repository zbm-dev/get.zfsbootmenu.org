FROM ghcr.io/void-linux/void-linux:latest-full-x86_64
MAINTAINER dykstra.zachary@gmail.com

WORKDIR /usr/local/redirect

COPY cpanfile .
RUN xbps-install -Syu xbps && \
    xbps-install -Syu && \
    xbps-install -y perl cpanminus make gcc openssl-devel file && \
    cpanm --installdeps --notest . && \
    xbps-remove -Ry gcc make openssl-devel

COPY redirect.pl /usr/local/redirect

CMD ["/usr/bin/hypnotoad", "-f", "/usr/local/redirect/redirect.pl" ]
