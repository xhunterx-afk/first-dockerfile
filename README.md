## Synshopware:
- synshopware is a docker image that is made by me to dun shopware 6 on it with my
own preferences that has NGINX, MARIADB, PHP8.2, REDIS, NODE, XDEBUG ADMINER
NVM,  NPM, MAILCATCHER, Elasticsearch SHOPWARE SFTP (inspired by dockware)

### packges:
- #### debian:
- wget, sudo, curl, unzip, nano, gnupg2, gpg-agent, ,tzdata, xdg-utils,
libsodium-dev, net-tools, git tar, gosu, jq, vim, cron, composer, php,
nginx, sftp

- #### php:
- php8.1 + php8.2 configurations: phpV-fpm, phpV-mysql, phpV-curl, phpV-gd,
phpV-xml, phpV-zip, phpV-opcache, phpV-mbstring, phpV-intl, phpV-cli, phpV-ctype, 
phpV-mysqli, phpV-xmlreader, phpV-phar, phpV-dom, phpV-apcu, phpV-pcov, phpV-ssh2,
phpV-redis, php8.2-dev, phpizeV

- #### nginx:
- ssl, openssl, openssh-server, ssmtp,

- #### xdebug:
- xdebug-3.2.0

- #### mariadb:
- #### redis:
- #### adminer:
- #### elasticsearch:
- #### mailcatcher:
- #### node: 
- NODE 18
- #### Shopware:
- shopware 6

### passwords / users:
#### adminer:
- user: synshopware
- password: synshopware
- port: 81
#### shopware 6 admin:
- user: admin
- password: shopware
- port: 80
#### mariadb:
- user: synshopware
- password: synshopware
- host: localhost / 127.0.0.1
- port: 3306
#### redis:
- password: synshopware
- port: 6379
#### sftp: 
- user: synshopware
- password: synshopware