#!/bin/bash



echo "░██████╗██╗░░░██╗███╗░░██╗░██████╗██╗░░██╗░█████╗░██████╗░░██╗░░░░░░░██╗░█████╗░██████╗░███████╗"
echo "██╔════╝╚██╗░██╔╝████╗░██║██╔════╝██║░░██║██╔══██╗██╔══██╗░██║░░██╗░░██║██╔══██╗██╔══██╗██╔════╝"
echo "╚█████╗░░╚████╔╝░██╔██╗██║╚█████╗░███████║██║░░██║██████╔╝░╚██╗████╗██╔╝███████║██████╔╝█████╗░░"
echo "░╚═══██╗░░╚██╔╝░░██║╚████║░╚═══██╗██╔══██║██║░░██║██╔═══╝░░░████╔═████║░██╔══██║██╔══██╗██╔══╝░░"
echo "██████╔╝░░░██║░░░██║░╚███║██████╔╝██║░░██║╚█████╔╝██║░░░░░░░╚██╔╝░╚██╔╝░██║░░██║██║░░██║███████╗"
echo "╚═════╝░░░░╚═╝░░░╚═╝░░╚══╝╚═════╝░╚═╝░░╚═╝░╚════╝░╚═╝░░░░░░░░╚═╝░░░╚═╝░░╚═╝░░╚═╝╚═╝░░╚═╝╚══════╝"

echo "                                                    "
echo "                                              ______ "
echo "                                             /      \  "
echo "                                            /   __   \ "
echo "                                           /   /  \   \ "
echo "                                           \   \__/   / "
echo "                                            \        /   "
echo "                                             \______/     "

set -e

source /var/www/.bashrc

export BASH_ENV=/var/www/.bashrc

CONTAINER_STARTUP_DIR=$(pwd)

file="/var/www/boot_start.sh"
if [ -f "$file" ] ; then
    sh $file
fi


sudo service mariadb start
echo "-----------------------------------------------------------------------------------------------"
sudo service php8.2-fpm start
echo""
echo "-----------------------------------------------------------------------------------------------"
sudo service nginx start
echo ""
echo "-----------------------------------------------------------------------------------------------"
sudo service redis-server start
echo "-----------------------------------------------------------------------------------------------"

sudo /usr/bin/env $(which mailcatcher) --ip=0.0.0.0
echo "MAILCATCHER URL: http://localhost:1080/"



if [ $SSH_USER != "not-set" ] && (! id -u "${SSH_USER}" >/dev/null 2>&1 ); then
    echo "Synshopware: creating additional SSH user...."
    sudo adduser --disabled-password --uid 8888 --gecos "" --ingroup www-data $SSH_USER
    sudo usermod -a -G sudo $SSH_USER
    sudo usermod -m -d /var/www $SSH_USER | true
    sudo echo "${SSH_USER}:${SSH_PWD}" | sudo chpasswd
    sudo sed -i "s/${SSH_USER}:x:8888:33:/${SSH_USER}:x:33:33:/g" /etc/passwd
    sudo echo "${SSH_USER}" >> /tmp/user.name
    sudo -u root sh -c 'echo "Defaults:$(cat /tmp/user.name) !requiretty" >> /etc/sudoers'
    sudo rm -rf /tmp/user.name
    sudo usermod -s /bin/false synshopware
    sudo sed -i "s/AllowUsers synshopware/AllowUsers ${SSH_USER}/g" /etc/ssh/sshd_config
    echo "-----------------------------------------------------------------------------------------------"
fi

echo ""
echo "-----------------------------------------------------------------------------------------------"
sudo service ssh restart



sudo mysql --user=root --password=root -e "GRANT ALL PRIVILEGES ON *.* TO root@'%' IDENTIFIED BY 'root';FLUSH PRIVILEGES;"


if [ "$MYSQL_USER" != "not-set" ] && [ "$MYSQL_PWD" != "not-set" ]; then
  echo "-----------------------------------------------------------------Creating a new MYSQL user.... "

    sudo mysql --user=root --password=root -e "CREATE USER IF NOT EXISTS '"$MYSQL_USER"'@'%' IDENTIFIED BY '"$MYSQL_PWD"';";
    sudo mysql --user=root --password=root -e "use mysql; update user set host='%' where user='$MYSQL_USER';";
    sudo mysql --user=root --password=root -e "GRANT ALL PRIVILEGES ON *.* TO '"$MYSQL_USER"'@'%' IDENTIFIED BY '$MYSQL_PWD';";

    sudo mysql --user=root --password=root -e "FLUSH PRIVILEGES;";

    echo"---------------------a new MYSQL user has been added Welcome $MYSQL_USER-----------------------"
fi



if [[ ! -z "$NODE_VERSION" ]]; then
   echo ""
   echo "------------------------------Switching to Node ${NODE_VERSION}--------------------------------"
   nvm alias default ${NODE_VERSION}
   sudo rm -f /usr/local/bin/node
   sudo rm -f /usr/local/bin/npm
   sudo ln -s "$(which node)" "/usr/local/bin/node"
   sudo ln -s "$(which npm)" "/usr/local/bin/npm"
   echo "-----------------------------------------------------------------------------------------------"
fi

if [ $XDEBUG_ENABLED = 1 ]; then
   sh /var/www/scripts/xDebugScripts/xdebug_enable.sh
 else
   sh /var/www/scripts/xDebugScripts/xdebug_disable.sh
fi

if [ $SHOP_DOMAIN != "localhost" ]; then
    echo "----------------------------------------------------------Updating domain to ${SHOP_DOMAIN}..."
    sh /var/www/scripts/shopware/update_domain.sh
    echo "-----------------------------------------------------------------------------------------------"
fi

if [ $SW_CURRENCY != "not-set" ]; then
  echo "----------------------------------------------------------Switching Shopware default currency..."
  php /var/www/scripts/shopware/set_currency.php $SW_CURRENCY
   echo "-----------------------------------------------------------------------------------------------"
fi

if [ $SW_API_ACCESS_KEY != "not-set" ]; then
  echo "-----------------------------------------------------------------Set Shopware API access key..."
  ACTUAL_API_ACCESS_KEY=$(php /var/www/scripts/shopware/set_api_key.php $SW_API_ACCESS_KEY)
  echo "-----------------------------------------------------------------------------------------------"
fi
echo "----------------------------------------------------------------------------Restarting NGINX..."
sudo service nginx restart
echo "-----------------------------------------------------------------------------------------------"
echo "-------------------------------------------------------------------------------Testing NGINX..."
sudo nginx -t
echo "-----------------------------------------------------------------------------------------------"

cd $CONTAINER_STARTUP_DIR

file="/var/www/boot_end.sh"
if [ -f "$file" ] ; then
    sh $file
fi

if [[ -z "${BUILD_PLUGIN}" ]]; then
    echo ""
else
    echo "STARTING IN PLUGIN BUILDING MODE...."
    echo "Synshopware WILL NOW BUILD YOUR PLUGIN AND EXIT THE CONTAINER AFTERWARDS"
    echo ""

    cd /var/www/html && php bin/console plugin:refresh && \
    cd /var/www/html && php bin/console plugin:install --activate "${BUILD_PLUGIN}"
    cd /var/www/html && ./bin/build-js.sh

    export Synshopware_CI=1
    fi

exec "$@"

if [[ ! -z "$Synshopware_CI" ]]; then

    echo ""
else
    tail -f /dev/null
fi
