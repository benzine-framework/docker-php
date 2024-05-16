# checkov:skip=CKV_DOCKER_3 user cannot be determined at this stage.
FROM marshall:build AS php-core
LABEL maintainer="Matthew Baggett <matthew@baggett.me>" \
      org.label-schema.vcs-url="https://github.com/benzine-framework/docker" \
      org.opencontainers.image.source="https://github.com/benzine-framework/docker" \
      org.opencontainers.image.description="Build of Marshall with PHP"

ARG PHP_PACKAGES
ARG COMPOSER_VERSION
ENV COMPOSER_ALLOW_SUPERUSER=1
COPY core/install-report.sh /usr/bin/install-report
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN echo "Acquire::Retries \"5\";" > /etc/apt/apt.conf.d/80-retries && \
    echo "Acquire::http::No-Cache=true;" > /etc/apt/apt.conf.d/80-no-cache && \
    echo "Acquire::http::Pipeline-Depth=0;" > /etc/apt/apt.conf.d/80-no-pipeline && \
    apt-get -qq update && \
    apt-get -yqq upgrade && \
    apt-get -yqq install --no-install-recommends \
        python3-software-properties \
        software-properties-common \
        && \
    echo "PHP packages to install:" && echo $PHP_PACKAGES && \
    add-apt-repository -y ppa:ondrej/php && \
    apt-get -qq update && \
    apt-get -yqq install --no-install-recommends $PHP_PACKAGES  &&\
    apt-get remove -yqq \
        software-properties-common \
        python-apt-common \
        python3-software-properties \
        python3.5 python3.5-minimal libpython3.5-minimal \
        && \
    apt-get autoremove -yqq && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/lib/dpkg/status.old /var/cache/debconf/templates.dat /var/log/dpkg.log /var/log/lastlog /var/log/apt/*.log && \
    rm -rf  /usr/bin/mariabackup \
            /usr/bin/mysql_embedded \
            /usr/bin/mysql_find_rows \
            /usr/bin/mysql_fix_extensions \
            /usr/bin/mysql_waitpid \
            /usr/bin/mysqlaccess \
            /usr/bin/mysqlanalyze \
            /usr/bin/mysqlcheck \
            /usr/bin/mysqldump \
            /usr/bin/mysqldumpslow \
            /usr/bin/mysqlimport \
            /usr/bin/mysqloptimize \
            /usr/bin/mysqlrepair \
            /usr/bin/mysqlreport \
            /usr/bin/mysqlshow \
            /usr/bin/mysqlslap \
            /usr/bin/mytop

RUN chmod +x /usr/bin/install-report && \
    /usr/bin/install-report

RUN curl https://getcomposer.org/download/$COMPOSER_VERSION/composer.phar --output /usr/local/bin/composer && \
    chmod +x /usr/local/bin/composer /usr/bin/install-report && \
    composer self-update

# Healthcheck is nonsensical for this container.
HEALTHCHECK NONE

# checkov:skip=CKV_DOCKER_3 user cannot be determined at this stage.
FROM php-core AS php-cli
LABEL maintainer="Matthew Baggett <matthew@baggett.me>" \
      org.label-schema.vcs-url="https://github.com/benzine-framework/docker" \
      org.opencontainers.image.source="https://github.com/benzine-framework/docker"

# Install a funky cool repl.
RUN composer global require -q psy/psysh:@stable && \
    ln -s /root/.composer/vendor/psy/psysh/bin/psysh /usr/local/bin/repl && \
    /usr/local/bin/repl -v && \
    composer clear-cache

COPY cli/psysh-config.php /root/.config/psysh/config.php

RUN composer --version && \
    repl --version

# checkov:skip=CKV_DOCKER_3 user cannot be determined at this stage.
FROM php-cli AS php-nginx
LABEL maintainer="Matthew Baggett <matthew@baggett.me>" \
      org.label-schema.vcs-url="https://github.com/benzine-framework/docker" \
      org.opencontainers.image.source="https://github.com/benzine-framework/docker" \
      org.opencontainers.image.description="Build of Marshall with Nginx + PHP"

ARG PHP_VERSION
ARG PHP_MEMORY_LIMIT=128M
ARG PHP_DATA_MAX_SIZE=1024M
ENV PHPFPM_MAX_CHILDREN=25
COPY nginx /conf
COPY self-signed-certificates /certs

# ts:skip=AC_DOCKER_0002 Mis-detecting usage of apt instead of apt-get
RUN apt-get -qq update && \
    # Install pre-dependencies to use apt-key.
    apt-get -yqq install --no-install-recommends \
        lsb-core \
        gnupg \
        && \
    # Add nginx ppa
    sh -c 'echo "deb http://ppa.launchpad.net/nginx/stable/ubuntu $(lsb_release -sc) main" \
            > /etc/apt/sources.list.d/nginx-stable.list' && \
    # Add nginx key
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys C300EE8C && \
    apt-get -qq update && \
    apt-get -yqq install --no-install-recommends \
        nginx \
        php$PHP_VERSION-fpm \
        certbot \
        python3-certbot-nginx \
        && \
    apt-get remove -yqq \
        lsb-core \
        cups-common \
        && \
    apt-get autoremove -yqq && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/lib/dpkg/status.old /var/cache/debconf/templates.dat /var/log/dpkg.log /var/log/lastlog /var/log/apt/*.log && \
    # Configure FPM
    sed -i "s/cgi.fix_pathinfo.*/cgi.fix_pathinfo=0/g" /etc/php/$PHP_VERSION/fpm/php.ini && \
    sed -i "s|memory_limit.*|memory_limit = $PHP_MEMORY_LIMIT|g" /etc/php/$PHP_VERSION/fpm/php.ini && \
    sed -i "s/upload_max_filesize.*/upload_max_filesize = $PHP_DATA_MAX_SIZE/g" /etc/php/$PHP_VERSION/fpm/php.ini && \
    sed -i "s/post_max_size.*/post_max_size = $PHP_DATA_MAX_SIZE/g" /etc/php/$PHP_VERSION/fpm/php.ini  && \
    sed -i "s/max_execution_time.*/max_execution_time = 0/g" /etc/php/$PHP_VERSION/fpm/php.ini && \
    sed -i "s/variables_order.*/variables_order = \"EGPCS\"/g" /etc/php/$PHP_VERSION/fpm/php.ini  && \
    sed -i "s/error_reporting.*/error_reporting = E_ALL \& \~E_DEPRECATED \& \~E_STRICT \& \~E_CORE_WARNING/g" /etc/php/$PHP_VERSION/fpm/php.ini && \
    # FPM logging to file
    sed -i "s|;catch_workers_output.*|catch_workers_output = yes|g" /etc/php/$PHP_VERSION/fpm/pool.d/www.conf && \
    sed -i "s|;php_flag\[display_errors\].*|php_flag\[display_errors\] = on|g" /etc/php/$PHP_VERSION/fpm/pool.d/www.conf && \
    sed -i "s|;php_admin_value\[error_log\].*|php_admin_value\[error_log\] = /var/log/fpm-php.log|g" /etc/php/$PHP_VERSION/fpm/pool.d/www.conf && \
    sed -i "s|;php_admin_flag\[log_errors\].*|php_admin_flag\[log_errors\] = on|g" /etc/php/$PHP_VERSION/fpm/pool.d/www.conf && \
    sed -i "s|;php_admin_value\[memory_limit\].*|php_admin_value\[memory_limit\] = $PHP_MEMORY_LIMIT|g" /etc/php/$PHP_VERSION/fpm/pool.d/www.conf && \
    # Symlink FPM config to CLI & PHPDBG
    rm -f /etc/php/$PHP_VERSION/cli/php.ini  && \
    ln -s /etc/php/$PHP_VERSION/fpm/php.ini /etc/php/$PHP_VERSION/cli/php.ini && \
    # Configuration step for clear_env=no
    echo "clear_env=no" >> /etc/php/$PHP_VERSION/fpm/php-fpm.conf; \
    echo "clear_env=no" >> /etc/php/$PHP_VERSION/fpm/pool.d/www.ini; \
    # Create run lock dir for php
    mkdir -p /run/php && \
    # Destroy default html root, and link /app in its place.
    rm -fr /var/www/html && \
    mkdir -p /var/www && \
    ln -s /app /var/www/html && \
    # Move nginx configuration into place
    mv /conf/NginxDefault /etc/nginx/sites-enabled/default && \
    mv /conf/NginxSSL /etc/nginx/sites-enabled/default-ssl && \
    # Generate self-signed certificates
    #mkdir /certs && \
    #openssl req -x509 -nodes -days 36500 -newkey rsa:2048 \
    #    -subj "/C=US/ST=Florida/L=Miami/O=Example Group/CN=example.org" \
    #    -keyout /certs/example.key \
    #    -out /certs/example.crt \
    #&& \
    # Create runit service directories
    mkdir -p /etc/service/nginx \
             /etc/service/php-fpm \
             /etc/service/letsencrypt \
             #/etc/service/logs-letsencrypt \
             /etc/service/logs-nginx-access \
             /etc/service/logs-nginx-error \
             /etc/service/logs-phpfpm-error && \
    # Copy our new service runits into location
    mv /conf/nginx.runit /etc/service/nginx/run && \
    mv /conf/php-fpm.runit /etc/service/php-fpm/run && \
    mv /conf/letsencrypt.runit /etc/service/letsencrypt/run && \
    #mv /conf/logs-letsencrypt.runit /etc/service/logs-letsencrypt/run && \
    #mv /conf/logs-letsencrypt.finish /etc/service/logs-letsencrypt/finish && \
    mv /conf/logs-nginx-access.runit /etc/service/logs-nginx-access/run && \
    mv /conf/logs-nginx-error.runit /etc/service/logs-nginx-error/run && \
    mv /conf/logs-phpfpm-error.runit /etc/service/logs-phpfpm-error/run && \
    mv /conf/logs-phpfpm-error.finish /etc/service/logs-phpfpm-error/finish && \
    # Make sure all our new services are using unix line endings
    dos2unix -q /etc/service/*/run /etc/service/*/finish && \
    # Make sure all our new services are executable
    chmod +x /etc/service/*/run /etc/service/*/finish && \
    # Cleanup the /conf dir
    rm -R /conf && \
    # Write the PHP version into some template locations
    sed -i "s/{{PHP}}/$PHP_VERSION/g" /etc/nginx/sites-enabled/default && \
    sed -i "s/{{PHP}}/$PHP_VERSION/g" /etc/nginx/sites-enabled/default-ssl && \
    sed -i "s/{{PHP}}/$PHP_VERSION/g" /etc/service/php-fpm/run && \
    sed -i "s/{{PHP}}/$PHP_VERSION/g" /etc/service/logs-phpfpm-error/run && \
    # Enable PHP-FPM status & PHP-FPM ping
    sed -i -e "s|;pm.status_path =.*|pm.status_path = /fpm-status|g" /etc/php/*/fpm/pool.d/www.conf && \
    sed -i -e "s|;ping.path =.*|ping.path = /fpm-ping|g" /etc/php/*/fpm/pool.d/www.conf && \
    # Using environment variables in config files works, it would seem. Neat!
    sed -i -e "s|pm.max_children = 5|pm.max_children = \${PHPFPM_MAX_CHILDREN}|g" /etc/php/*/fpm/pool.d/www.conf && \
    # Disable daemonising in nginx
    sed -i '1s;^;daemon off\;\n;' /etc/nginx/nginx.conf

# Expose ports.
EXPOSE 80/tcp
EXPOSE 443/tcp

# Make a volume for letsencrypt certs
VOLUME /etc/letsencrypt

# Create a healthcheck that makes sure our httpd is up
HEALTHCHECK --interval=30s --timeout=3s \
    CMD curl -f http://localhost/ || exit 1

# checkov:skip=CKV_DOCKER_3 user cannot be determined at this stage.
FROM php-cli AS php-apache
LABEL maintainer="Matthew Baggett <matthew@baggett.me>" \
      org.label-schema.vcs-url="https://github.com/benzine-framework/docker" \
      org.opencontainers.image.source="https://github.com/benzine-framework/docker" \
      org.opencontainers.image.description="Build of Marshall with Apache + PHP"

ARG PHP_VERSION
# ts:skip=AC_DOCKER_0002 Mis-detecting usage of apt instead of apt-get
RUN apt-get -qq update && \
    apt-get -yqq install --no-install-recommends \
        apache2 \
        libapache2-mod-php$PHP_VERSION \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/lib/dpkg/status.old /var/cache/debconf/templates.dat /var/log/dpkg.log /var/log/lastlog /var/log/apt/*.log && \
    sed -i "s/upload_max_filesize.*/upload_max_filesize = $PHP_DATA_MAX_SIZE/g" /etc/php/$PHP_VERSION/apache2/php.ini && \
    sed -i "s/post_max_size.*/post_max_size = $PHP_DATA_MAX_SIZE/g" /etc/php/$PHP_VERSION/apache2/php.ini && \
    sed -i "s/max_execution_time.*/max_execution_time = 0/g" /etc/php/$PHP_VERSION/apache2/php.ini && \
    sed -i "s/variables_order.*/variables_order = \"EGPCS\"/g" /etc/php/$PHP_VERSION/apache2/php.ini && \
    sed -i "s/error_reporting.*/error_reporting = E_ALL \& \~E_DEPRECATED \& \~E_STRICT \& \~E_CORE_WARNING/g" /etc/php/$PHP_VERSION/apache2/php.ini && \
    cp /etc/php/$PHP_VERSION/apache2/php.ini /etc/php/$PHP_VERSION/cli/php.ini && \
    sed -i "s/ServerSignature On/ServerSignature Off/g" /etc/apache2/conf-enabled/security.conf && \
    sed -i "s/ServerTokens OS/ServerTokens Prod/g" /etc/apache2/conf-enabled/security.conf

# Expose ports.
EXPOSE 80

# Create a healthcheck that makes sure our httpd is up
HEALTHCHECK --interval=30s --timeout=3s \
    CMD curl -f http://localhost/ || exit 1

COPY apache /conf
RUN rm -fr /var/www/html && \
    ln -s /app /var/www/html && \
    mv /conf/ApacheConfig.conf /etc/apache2/sites-enabled/000-default.conf && \
    mv /conf/envvars /etc/apache2/ && \
    mv /conf/apache2.conf /etc/apache2/ && \
    mkdir -p /etc/service/apache && \
    mkdir -p /etc/service/show_logs && \
    mv /conf/apache.runit /etc/service/apache/run && \
    mv /conf/show_logs.runit /etc/service/show_logs/run && \
    chmod +x /etc/service/*/run && \
    rm -Rf /conf && \
    a2enmod rewrite
