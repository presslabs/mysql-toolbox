FROM alpine:3.7 as builder
RUN apk add --no-cache \
        autoconf \
        automake \
        binutils \
        bison \
        build-base \
        cmake \
        cppunit-dev \
        curl-dev \
        g++ \
        gcc \
        git \
        glib-dev \
        gzip \
        libaio-dev \
        libc-dev \
        libev-dev \
        libgcrypt-dev \
        libressl-dev \
        libtool \
        linux-headers \
        mariadb-dev \
        musl-dev \
        mysql-client \
        ncurses-dev \
        pcre-dev \
        tar \
        vim \
        wget \
        xz \
        zlib-dev
RUN apk add --no-cache \
        ca-certificates \
        coreutils \
        curl \
        glib \
        libaio \
        libev \
        libgcc \
        libgcrypt \
        libressl \
        libstdc++ \
        ncurses \
        openssl \
        pcre \
        perl \
        perl-dbd-mysql \
        perl-time-hires \
        zlib

ARG XTRABACKUP_VERSION=2.4.9
WORKDIR /usr/src/percona-xtrabackup
RUN set -ex \
    && wget -q https://github.com/percona/percona-xtrabackup/archive/percona-xtrabackup-${XTRABACKUP_VERSION}.tar.gz -O- | \
        tar -zx -C /usr/src/percona-xtrabackup --strip-components=1

ARG BOOST_VERSION=1.59.0
RUN set -ex \
    && mkdir -p /usr/src/boost \
    && wget http://sourceforge.net/projects/boost/files/boost/${BOOST_VERSION}/boost_$(echo ${BOOST_VERSION} | tr '.' '_').tar.gz -O- | \
        tar -zx -C /usr/src/boost --strip-components=1

# workaround https://bugs.mysql.com/bug.php?id=80322
COPY fix-posix_timers.patch /usr/src
RUN set -ex \
    && patch -i ../fix-posix_timers.patch -p1
ENV CFLAGS="-DSIGEV_THREAD_ID=4"
# done

RUN set -ex \
    && cmake \
        -DBUILD_CONFIG=xtrabackup_release \
        -DWITH_MAN_PAGES=OFF \
        -DWITH_BOOST=/usr/src/boost \
    && make -j8 \
    && make install

ARG PERCONA_TOOLKIT_VERSION=3.0.8
WORKDIR /usr/src/percona-toolkit
RUN set -ex \
    && wget https://www.percona.com/downloads/percona-toolkit/${PERCONA_TOOLKIT_VERSION}/binary/tarball/percona-toolkit-${PERCONA_TOOLKIT_VERSION}_x86_64.tar.gz -O- | \
        tar -zx -C /usr/src/percona-toolkit --strip-components=1 \
    && cd /usr/src/percona-toolkit \
    && perl Makefile.PL PREFIX=/usr/local/percona-toolkit \
    && make \
    && make install

WORKDIR /usr/src/mydumper
ARG MYDUMPER_VERSION=0.9.3
RUN set -ex \
    && wget https://github.com/maxbube/mydumper/archive/v${MYDUMPER_VERSION}.tar.gz -O- | \
        tar -zx -C /usr/src/mydumper --strip-components=1 \
    && cmake -DBUILD_DOCS=OFF -DCMAKE_INSTALL_PREFIX=/usr/local/mydumper . \
    && make \
    && make install

RUN set -ex \
    && strip /usr/local/xtrabackup/bin/* /usr/local/mydumper/bin/* || true


# The slim image...
FROM alpine:3.7
COPY --from=builder /usr/local/xtrabackup/bin/x* /usr/local/percona-toolkit/bin/pt* /usr/local/mydumper/bin/* /usr/local/bin/
RUN set -ex \
    && ln -sf /usr/local/bin/xtrabackup /usr/local/bin/innobackupex \
    && apk add --no-cache \
        bash \
        ca-certificates \
        coreutils \
        curl \
        glib \
        libaio \
        libev \
        libgcc \
        libgcrypt \
        libressl \
        libstdc++ \
        mysql \
        mysql-client \
        ncurses \
        nmap-ncat \
        openssh-client \
        openssl \
        pcre \
        perl \
        perl-dbd-mysql \
        perl-time-hires \
        unzip \
        zlib \
    && wget https://downloads.rclone.org/rclone-current-linux-amd64.zip \
    && unzip rclone-current-linux-amd64.zip \
    && mv rclone-*-linux-amd64/rclone /usr/local/bin/ \
    && rm -rf rclone-*-linux-amd64 rclone-current-linux-amd64.zip \
    && chmod 755 /usr/local/bin/rclone
