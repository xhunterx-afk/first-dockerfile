FROM debian:12
LABEL authors="Saeb" \
       title="shadowcodes synshopware:latest" \
       version="0.0.1"


RUN mkdir -p  /var/www \
    && mkdir -p /var/www/scripts

## ***********************************************************************
##  IMAGE VARIABLES
## ***********************************************************************
ENV TZ Europe/Berlin
ENV PHP_VERSION 8.2
ENV XDEBUG_ENABLED 1
ENV NODE_VERSION 18
ENV NGINX_DOCROOT /var/www/html
ENV COMPOSER_VERSION not-set
ENV SSH_USER not-set
ENV SSH_PWD not-set
ENV MYSQL_USER not-set
ENV MYSQL_PWD not-set
ENV XDEBUG_REMOTE_HOST "host.docker.internal"
ENV XDEBUG_CONFIG "idekey=PHPSTORM"
ENV PHP_IDE_CONFIG "serverName=localhost"
ENV SW_CURRENCY 'not-set'
ENV SW_API_ACCESS_KEY 'not-set'


RUN echo "export PHP_VERSION=${PHP_VERSION}" >> /etc/profile \
  && echo "export COMPOSER_VERSION=${COMPOSER_VERSION}" >> /etc/profile \
  && echo "export NODE_VERSION=${NODE_VERSION}" >> /etc/profile \
  && echo "export DOCUMENT_ROOT=${NGINX_DOCROOT}" >> /etc/profile \
  && echo "export SSH_USER=${SSH_USER}" >> /etc/profile \
  && echo "export SSH_PWD=${SSH_PWD}" >> /etc/profile \
  && echo "export MYSQL_USER=${MYSQL_USER}" >> /etc/profile \
  && echo "export MYSQL_PWD=${MYSQL_PWD}" >> /etc/profile \
  && echo "export XDEBUG_ENABLED=${XDEBUG_ENABLED}" >> /etc/profile \
  && echo "export XDEBUG_REMOTE_HOST=${XDEBUG_REMOTE_HOST}" >> /etc/profile \
  && echo "export XDEBUG_CONFIG=${XDEBUG_CONFIG}" >> /etc/profile \
  && echo "export PHP_IDE_CONFIG=${PHP_IDE_CONFIG}" >> /etc/profile \
  && echo "export SW_CURRENCY=${SW_CURRENCY}" >> /etc/profile \
  && echo "export SW_API_ACCESS_KEY=${SW_API_ACCESS_KEY}" >> /etc/profile \
  && echo "export TZ=${TZ}" >> /etc/profile



## ***********************************************************************
##  BASE REQUIREMENTS
## ***********************************************************************

RUN apt-get update && apt-get install -y  \
    wget sudo curl unzip nano gnupg2 gpg-agent php-dev php-pear \
    tzdata xdg-utils libsodium-dev openssl openssh-server net-tools git tar \
    gosu ssmtp jq vim cron \
    && mkdir run/sshd \
    && ln -fs /usr/share/zoneinfo/Europe/Berlin /etc/localtime \
    && dpkg-reconfigure --frontend noninteractive tzdata  \
    && apt-get remove -y php-pear \
    && apt-get remove -y php-dev \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/*


## ***********************************************************************
##  USER MANAGEMENT
## ***********************************************************************

RUN echo "root:root" | chpasswd \
    && echo 'www-data:www-data' | chpasswd \
    && usermod -s /usr/sbin/nologin www-data \
    && sed -i 's/PermitRootLogin without-password//' /etc/ssh/sshd_config \
    && sed -i 's/PermitRootLogin prohibit-password//' /etc/ssh/sshd_config \
    && sed -i /etc/sudoers -re 's/^%sudo.*/%sudo ALL=(ALL:ALL) NOPASSWD: ALL/g' \
    && sed -i /etc/sudoers -re 's/^root.*/root ALL=(ALL:ALL) NOPASSWD: ALL/g' \
    && sed -i /etc/sudoers -re 's/^#includedir.*/## **Removed the include directive** ##"/g'


RUN adduser --disabled-password --uid 5577 --gecos "" --ingroup www-data synshopware \
    && usermod -m -d /var/www synshopware | true \
    && echo "synshopware:synshopware" | chpasswd \
    && usermod -a -G sudo synshopware \
    && echo "Defaults:synshopware !requiretty" >> /etc/sudoers \
    && sed -i 's/synshopware:x:5577:33:/synshopware:x:33:33:/g' /etc/passwd

RUN echo 'AllowUsers synshopware' >> /etc/ssh/sshd_config

ENV BASH_ENV /var/www/.bashrc

RUN echo "source /var/www/.nvm/nvm.sh" >> /var/www/.bashrc \
    && chown 33:33 /var/www/.bashrc \
    && echo "export BASH_ENV=${BASH_ENV}" >> /etc/profile

## ***********************************************************************
##  NGINX INSTALLATION + SETUP
## ***********************************************************************

RUN apt-get update && apt-get install -y nginx

# Configure nginx - http
COPY config/nginx/nginx.conf /etc/nginx/nginx.conf
# Configure nginx - default server
COPY config/conf.d /etc/nginx/sites-available

COPY config/nginx/status.conf /etc/nginx/conf.d/status.conf

RUN mkdir -p /var/www/html \
    && rm -rf /var/www/html/* \
    && chown -R www-data:www-data /var/www/html \
    && sudo -u www-data sh -c 'mkdir -p /var/www/html/public'


RUN mkdir -p /var/www/.ssh \
    && rm -rf /var/www/.ssh/id_rsa; true  \
    && rm -rf /var/www/.ssh/id_rsa.pub; true  \
    && ssh-keygen -t rsa -b 4096 -f /var/www/.ssh/id_rsa -C "synshopware Container" -P ""  \
    && chown -R www-data:www-data /var/www/.ssh \
    && chmod 0700 /var/www/.ssh

## ***********************************************************************
##  MOD_SSL
##  create SSL certificate
## ***********************************************************************

RUN sudo mkdir /etc/nginx/ssl \
    && openssl req -new -x509 -days 365 -sha1 -newkey rsa:2048 -nodes -keyout /etc/nginx/ssl/server.key -out /etc/nginx/ssl/server.crt -subj '/O=Company/OU=Department/CN=localhost'


## ***********************************************************************
##  COMPOSER INSTALLATION + SETUP
## ***********************************************************************
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"  \
    && mkdir -p /var/www/.composer \
    && chmod 755 -R /var/www/.composer \
    && export COMPOSER_HOME="/var/www/.composer" \
    && php composer-setup.php --install-dir=/usr/local/bin --filename=composer \
    && chmod 755 /usr/local/bin/composer

## ***********************************************************************
##  PHP INSTALLATION + SETUP
## ***********************************************************************

RUN curl https://packages.sury.org/php/README.txt | bash

RUN apt-get update && apt-get install -y \
    php8.1-fpm php8.1-mysql php8.1-curl php8.1-gd php8.1-xml php8.1-zip \
    php8.1-opcache php8.1-mbstring php8.1-intl php8.1-cli php8.1-ctype  \
    php8.1-mysqli php8.1-xmlreader php8.1-phar php8.1-dom \
    php8.1-apcu php8.1-pcov php8.1-ssh2 php8.1-redis \
    php8.2-fpm php8.2-mysql php8.2-curl php8.2-gd php8.2-xml php8.2-zip \
    php8.2-opcache php8.2-mbstring php8.2-intl php8.2-cli php8.2-ctype  \
    php8.2-mysqli php8.2-xmlreader php8.2-phar php8.2-dom \
    php8.2-apcu php8.2-pcov php8.2-ssh2 php8.1-redis \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/* \
    && sudo service php8.2-fpm start

# Configure PHP-FPM
COPY config/php/fpm-pool.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY config/php/php.ini /etc/php/8.2/conf.d/custom.ini
COPY config/php/general.ini /etc/php/8.2/fpm/conf.d/01-general.ini
COPY config/php/general.ini /etc/php/8.2/cli/conf.d/01-general.ini
COPY config/php/cli.ini /etc/php/8.2/cli/conf.d/01-general-cli.ini
COPY config/php/general.ini /etc/php/8.1/fpm/conf.d/01-general.ini
COPY config/php/general.ini /etc/php/8.1/cli/conf.d/01-general.ini
COPY config/php/cli.ini /etc/php/8.1/cli/conf.d/01-general-cli.ini

#make sure the installation runs also in default php version
RUN sudo update-alternatives --set php /usr/bin/php8.2 > /dev/null 2>&1 &
# make sure the installation runs using our default php version
RUN service php8.2-fpm stop > /dev/null 2>&1  \
    && service php8.2-fpm start \
    && sudo update-alternatives --set php /usr/bin/php8.2 > /dev/null 2>&1

# make sure our php user has rights on the session
RUN chown www-data:www-data -R /var/lib/php/sessions

# remove the standard nginx index file
RUN mkdir -p /var/www/html \
    && rm -rf /var/www/html/* \
    && chown -R www-data:www-data /var/www/html \
    && sudo -u www-data sh -c 'mkdir -p /var/www/html/public'

# make sure the configured log folder exists and is writeable
RUN sudo chmod -R 0777 /var/www \
    && chgrp -R www-data /var/log/nginx \
    && mkdir -p /var/log/mariadb \
    && chgrp -R www-data /var/log/mariadb \
    && mkdir /var/log/php -p  \
    && touch /var/log/php/cli_errors.log  \
    && touch /var/log/php/fpm_errors.log  \
    && chown -R www-data:www-data /var/log/php  \
    && chmod 0755 /var/log/php


## ***********************************************************************
##  XDEBUG INSTALLATION + SETUP
## ***********************************************************************
# install xdebug for php 8.2
RUN cd /var/www \
    && apt-get update \
    && sudo apt-get install -y php8.2-dev \
    && cd /var/www \
    && rm -rf xdebug \
    && wget https://github.com/xdebug/xdebug/archive/refs/tags/3.2.0.zip \
    && unzip 3.2.0.zip \
    && rm -rf 3.2.0.zip \
    && mv xdebug-3.2.0 xdebug \
    && cd /var/www/xdebug \
    && sudo apt-get update \
    && sudo phpize8.2 \
    && sudo ./configure --with-php-config=/usr/bin/php-config8.2 \
    && sudo make \
    && sudo cp /var/www/xdebug/modules/xdebug.so /usr/lib/php/20220829/xdebug_8.2.so \
    && make clean \
    && make distclean \
    && sudo phpize8.2 --clean \
    && sudo apt-get remove -y php8.2-dev

    # install xdebug for php 8.1
RUN sudo apt-get install -y php8.1-dev \
    && cd /var/www \
    && rm -rf xdebug \
    && wget https://github.com/xdebug/xdebug/archive/refs/tags/3.1.4.zip \
    && unzip 3.1.4.zip \
    && rm -rf 3.1.4.zip \
    && mv xdebug-3.1.4 xdebug \
    && cd /var/www/xdebug \
    && sudo apt-get update \
    && sudo phpize8.1 \
    && sudo ./configure --with-php-config=/usr/bin/php-config8.1 \
    && sudo make \
    && sudo cp /var/www/xdebug/modules/xdebug.so /usr/lib/php/20210902/xdebug_8.1.so \
    && make clean \
    && make distclean \
    && sudo phpize8.1 --clean \
    && sudo apt-get remove -y php8.1-dev \
    && sudo apt-get install -y zlib1g-dev \
    && sudo rm -rf /var/lib/apt/lists/* /var/cache/apt/* \
    && sudo rm -rf /var/www/xdebug

#generate xdebug ini files

COPY config/php/xdebug-3.ini /etc/php/8.2/fpm/conf.d/20-xdebug.ini
COPY config/php/xdebug-3.ini /etc/php/8.2/cli/conf.d/20-xdebug.ini

COPY config/php/xdebug-3.ini /etc/php/8.1/fpm/conf.d/20-xdebug.ini
COPY config/php/xdebug-3.ini /etc/php/8.1/cli/conf.d/20-xdebug.ini
# php8.2
RUN cd /var/www \
    && sed -i 's/__PHP__FOLDER__ID/20220829/g' /etc/php/8.2/fpm/conf.d/20-xdebug.ini \
    && sed -i 's/__PHP_VERSION__/8.2/g' /etc/php/8.2/fpm/conf.d/20-xdebug.ini \
    && sed -i 's/__PHP__FOLDER__ID/20220829/g' /etc/php/8.2/cli/conf.d/20-xdebug.ini \
    && sed -i 's/__PHP_VERSION__/8.2/g' /etc/php/8.2/cli/conf.d/20-xdebug.ini
 # php8.1
RUN sed -i 's/__PHP__FOLDER__ID/20210902/g' /etc/php/8.1/fpm/conf.d/20-xdebug.ini \
    && sed -i 's/__PHP_VERSION__/8.1/g' /etc/php/8.1/fpm/conf.d/20-xdebug.ini \
    && sed -i 's/__PHP__FOLDER__ID/20210902/g' /etc/php/8.1/cli/conf.d/20-xdebug.ini \
    && sed -i 's/__PHP_VERSION__/8.1/g' /etc/php/8.1/cli/conf.d/20-xdebug.ini \
    && cd /var/www


## ***********************************************************************
##  MARIADB INSTALL + SETUP
## ***********************************************************************

RUN export DEBIAN_FRONTEND=noninteractive \
    && echo debconf-set-selections mariadb-server mysql-server/root_password password root \
    && echo debconf-set-selections mariadb-server mysql-server/root_password password root  \
    && apt-get update \
    && sudo apt-get install -y mariadb-server\
    && usermod -d /var/lib/mysql/ mysql \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/* \
    && sudo service mariadb start


# copy custom configuration to the image and change rights
COPY config/mariadb/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

RUN sudo chmod 0644 /etc/mysql/mariadb.conf.d/50-server.cnf


## ***********************************************************************
##  REDIS INSTALL + SETUP
## ***********************************************************************

RUN curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list \
    && sudo apt-get update && apt-get -y install redis

COPY config/redis/redis.conf /etc/redis/redis.conf


## ***********************************************************************
##  Elasticsearch INSTALLATION + SETUP
## ***********************************************************************

RUN apt-get update \
    && wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add - \
    && apt-get install -y apt-transport-https \
    && echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | tee -a /etc/apt/sources.list.d/elastic-7.x.list \
    && apt-get update && apt-get install filebeat \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

## ***********************************************************************
##  ADMINER INSTALLATION + SETUP
## ***********************************************************************

RUN mkdir /usr/share/adminer \
    && wget "https://github.com/vrana/adminer/releases/download/v4.8.1/adminer-4.8.1.php" -O /usr/share/adminer/latest.php \
    && ln -s /usr/share/adminer/latest.php /usr/share/adminer/adminer.php


## ***********************************************************************
##  MAILCATCHER INSTALLATION + SETUP
## ***********************************************************************

RUN apt-cache search sqlite ruby

RUN apt-get update && apt-get install -y  \
    build-essential libsqlite3-dev rubygems \
    && apt-get install -y ruby ruby-dev \
    && gem install net-protocol -v 0.1.2 \
    && gem install net-smtp -v 0.3.0 \
    && gem install net-imap -v 0.2.2 \
    && gem install sqlite3 -v 1.3.4 \
    && gem install mailcatcher \
    && phpenmod mailcatcher \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

COPY ./config/ssmtp/ssmtp.conf /etc/ssmtp/ssmtp.conf

RUN echo "sendmail_path = /usr/bin/env $(which catchmail) -f 'local@synshopware'" >> /etc/php/8.2/mods-available/mailcatcher.ini \
    && echo "sendmail_path = /usr/bin/env $(which catchmail) -f 'local@synshopware'" >> /etc/php/8.1/mods-available/mailcatcher.ini \
    && echo ""

## ***********************************************************************
##  NVM + NPM + NODE.JS INSTALLATION + SETUP
## ***********************************************************************



RUN ls -la \
    && mkdir "/var/www/.nvm" \
    && export NVM_DIR="/var/www/.nvm" \
    && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash \
    && [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" \
    && [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  \
    && sudo apt-get update \
    && nvm install 18 \
    && nvm use 18 && npm install -g yarn \
    && nvm use 18 \
    && nvm alias default 18

ENV NODE_PATH $NVM_DIR/v$NODE_VERSION/lib/node_modules
ENV PATH      $NVM_DIR/v$NODE_VERSION/bin:$PATH

RUN export NVM_DIR="/var/www/.nvm" \
    && [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" \
    && [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  \
    && nvm use 18 \
    && mkdir /var/www/.npm \
    && npm config set cache /var/www/.npm \
    && chown 33:33 /var/www/.npm \
    && cd /var/www && npm install -g grunt-cli \
    && cd /var/www && npm install grunt --save-dev \
    && npm install -g --no-install-recommends yarn \
    && chown -R www-data:www-data /var/www/.composer \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

## ***********************************************************************
##  SHOPWARE INSTALLATION + SETUP
## ***********************************************************************
COPY config/php/xdebug/xDebugScripts /var/www/scripts/xDebugScripts
COPY config/shopware/scripts /var/www/scripts/shopware
COPY config/shopware/makefile /var/www/

#(preformance)
RUN chown www-data:www-data -R /var/www/scripts \
    && sh /var/www/scripts/xDebugScripts/xdebug_disable.sh \
    && chmod 755 /var/www/scripts/xDebugScripts/*.sh

RUN curl -1sLf 'https://dl.cloudsmith.io/public/symfony/stable/setup.deb.sh' | sudo -E bash \
    && sudo apt-get update && apt-get install -y symfony-cli \
    && composer require symfony/flex

RUN sudo service mariadb start \
    && sudo mysql --user=root --password=root -e "CREATE USER IF NOT EXISTS 'synshopware'@'localhost' IDENTIFIED BY 'synshopware';" \
    && sudo mysql --user=root --password=root -e "GRANT ALL PRIVILEGES ON *.* TO 'synshopware'@'localhost' IDENTIFIED BY 'synshopware';FLUSH PRIVILEGES;" \
    && cd /var/www/ \
    && composer create-project shopware/production --no-interaction tmp \
    && cp -a /var/www/tmp/. /var/www/html \
    && rm -rf /var/www/tmp \
    && sed -i "/APP_ENV=/g" /var/www/html/.env \
    && sed -i "/APP_URL=/g" /var/www/html/.env \
    && sed -i "/DATABASE_URL=/g" /var/www/html/.env \
    && sed -i "/MAILER_URL=/g" /var/www/html/.env \
    && echo "APP_ENV=dev" >> /var/www/html/.env  \
    && echo "APP_URL=http://localhost/" >> /var/www/html/.env \
    && echo "DATABASE_URL=mysql://synshopware:synshopware@127.0.0.1:3306/shopware" >> /var/www/html/.env \
    && echo "MAILER_URL=smtp://localhost:1025/" >> /var/www/html/.env \
    && sudo service mariadb stop


#    && cd /var/www/html && composer require --dev dev-tools \

COPY config/shopware/composer.json /var/www/html

RUN sudo chmod 644 /var/www/html/composer.json \
    && sudo chown -R 33:33 /var/www/html/composer.json


RUN sudo service mariadb start \
    && export COMPOSER_ALLOW_SUPERUSER=1 \
    && cd /var/www/html && composer require shopware/core:6.5.5.1 shopware/administration:6.5.5.1 shopware/elasticsearch:6.5.5.1 shopware/storefront:6.5.5.1 -W \
    && php bin/console system:install --create-database --basic-setup \
    && php bin/console assets:install \
    && composer require fakerphp/faker \
    && composer require mbezhanov/faker-provider-collection \
    && composer require maltyxx/images-generator \
    && composer require shopware/dev-tools \
    && APP_ENV=prod php bin/console store:download -p SwagPlatformDemoData  \
    && APP_ENV=prod php bin/console plugin:refresh  \
    && APP_ENV=prod php bin/console plugin:install --activate SwagPlatformDemoData  \
    && php bin/console cache:clear  \
    && php bin/console theme:change --all --no-compile --no-interaction Storefront  \
    && php bin/console theme:compile  \
    && php bin/console dal:refresh:index \
    && rm -rf /var/www/html/var/cache/* \
    && mysql --user=root --password=root -e "use shopware; INSERT INTO system_config (id, configuration_key, configuration_value, sales_channel_id, created_at, updated_at) VALUES (X'b3ae4d7111114377af9480c4a0911111', 'core.frw.completedAt', '{\"_value\": \"2019-10-07T10:46:23+00:00\"}', NULL, '2019-10-07 10:46:23.169', NULL);"  \
    && sudo service mariadb stop



## ***********************************************************************
##  END CONFIGS
## ***********************************************************************

ADD entrypoint.sh /entrypoint.sh

RUN curl -1sLf 'https://dl.cloudsmith.io/public/friendsofshopware/stable/setup.deb.sh' | sudo -E bash && sudo apt install shopware-cli \
    && chown 33:33 -R /var/www/html  \
    && mkdir -p /var/www/.npm && chown 33:33 /var/www/.npm -R  \
    && mkdir -p /var/www/.nvm && chown 33:33 /var/www/.nvm -R


USER synshopware

WORKDIR /var/www/html

CMD ["/bin/bash", "/entrypoint.sh"]
