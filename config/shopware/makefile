.PHONY: help
.DEFAULT_GOAL := help

PHP_VERSION_CURRENT=$(shell php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
XDEBUG_STATUS=$(shell php -r 'echo (int)extension_loaded("xdebug");')

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

status: ## status infos
	sh /var/www/scripts/bin/status.sh

xdebug-on: ## enables xdebug
	sh /var/www/scripts/bin/xdebug_enable.sh

xdebug-off: ## disables xdebug
	sh /var/www/scripts/bin/xdebug_disable.sh

permission-repair: ## repairs the general file permissions
	sudo chown -R www-data:www-data /var/www/html/*
	sudo chmod -R 775 /var/www/html
	cd /var/www/scripts/shopware && php set_permission.php
	cd /var/www/html/config/jwt && sudo chown www-data:www-data *

restart-php: ## Restarts FPM and Mariadb
	sudo service php$(PHP_VERSION_CURRENT)-fpm stop
	sudo service php$(PHP_VERSION_CURRENT)-fpm start
	@# ------------------------------------------------------
	sudo service mariadb restart

switch-php: ## Switches to another supported PHP version, [make switch-php version=7.4]
ifndef version
	$(warning Provide the required PHP version using "make switch-php version=x.y")
	@exit 1;
else
	@# --------------------------------------------------------------------------------------
	sudo service php$(version)-fpm start
	sudo service php$(PHP_VERSION_CURRENT)-fpm stop
	sudo service php$(version)-fpm start
	export PHP_VERSION=$(version)
	@# ---------------------------------------------------------------------------------------
	sudo sed -i 's/__synshopware_php_version__/'$(version)'/g' /etc/mariadb/sites-enabled/000-default.conf 2>/dev/null
	sudo sed -i 's/'php$(PHP_VERSION_CURRENT)-fpm.sock'/'php$(version)-fpm.sock'/g' /etc/mariadb/sites-enabled/000-default.conf
	sudo service mariadb restart
	@# ---------------------------------------------------------------------------------------
	sudo update-alternatives --set php /usr/bin/php$(version)
	@# ---------------------------------------------------------------------------------------
ifeq ($(XDEBUG_STATUS),1)
	make xdebug-on
else
	make xdebug-off
endif
	@# ---------------------------------------------------------------------------------------
	php -v
endif

# ---------------------------------------------------------------------------------------------
watch-storefront: ## starts watcher for Shopware 6 storefront at http://localhost
	@echo "RequestHeader add hot-reload-mode 1\n"\
	"RequestHeader add hot-reload-port 9999" > /var/www/html/.htaccess.watch
	cd /var/www/html && ./bin/build-storefront.sh
	cd /var/www/html && php bin/console theme:dump
	cd /var/www/html && ./bin/watch-storefront.sh

stop-watch-storefront: ## Reverts everything back to normal operation
	@rm -rf /var/www/html/.htaccess.watch

# ---------------------------------------------------------------------------------------------

watch-admin: ## starts watcher for Shopware 6 Admin at http://localhost:8888
	cd /var/www/html && ./bin/build-administration.sh
	cd /var/www/html && php bin/console bundle:dump
	cd /var/www/html && php bin/console feature:dump
	cd /var/www/html && APP_URL=http://0.0.0.0 PROJECT_ROOT=/var/www/html APP_ENV=dev PORT=8888 HOST=0.0.0.0 ENV_FILE=/var/www/html/.env ./bin/watch-administration.sh

# ---------------------------------------------------------------------------------------------
build-admin: ## builds the admin
	cd /var/www/html && ./bin/build-administration.sh
