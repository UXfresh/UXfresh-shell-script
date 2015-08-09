#!/bin/bash

# Varibale Config
# 

#
#  ========================
#      Domian Name
#  ========================
#

domain=$1

#
#  ========================
#      Get Hostname
#  ========================
#

url=$2

#
#  ========================
#      Get IP Server
#  ========================
#

ip_server=$(ifconfig eth0 2>/dev/null|awk '/inet addr:/ {print $2}'|sed 's/addr://')

#
#  ========================
#      Database Config
#  ========================
#

msqlpassroot=$(</dev/urandom tr -dc a-z0-9| (head -c $1 > /dev/null 2>&1 || head -c 9))
mysqldb=$(</dev/urandom tr -dc a-z0-9| (head -c $1 > /dev/null 2>&1 || head -c 9))
mysqluser=$(</dev/urandom tr -dc a-z0-9| (head -c $1 > /dev/null 2>&1 || head -c 9))
mysqluserpass=$(</dev/urandom tr -dc a-z0-9| (head -c $1 > /dev/null 2>&1 || head -c 9))

# 
#
#  ========================
#       SWAP
#  ========================
#

fallocate -l 1G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo "/swapfile   none    swap    sw    0   0" | tee -a /etc/fstab
sysctl vm.swappiness=10
echo "vm.swappiness=10" | tee -a /etc/sysctl.conf
sysctl vm.vfs_cache_pressure=50
echo "vm.vfs_cache_pressure=50" | tee -a /etc/sysctl.conf


# 
#
#  ========================
#       UFW Firewall
#  ========================
#

sudo apt-get install -y ufw
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
if systemctl is-active ufw > /dev/null; then
    notify-send "ufw active"
else
    notify-send "ufw inactive"
fi

#
#  ========================
#       Fail2ban
#  ========================
#

sudo apt-get install -y fail2ban
sudo service fail2ban start


#
#  ========================
#       Nginx
#  ========================
#

sudo add-apt-repository -y ppa:rtcamp/nginx
sudo apt-get update
sudo apt-get install -y nginx-custom


#
#  ========================
#       HHVM
#  ========================
#

sudo apt-get install software-properties-common
sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0x5a16e7281be7a449
sudo add-apt-repository "deb http://dl.hhvm.com/ubuntu $(lsb_release -sc) main"
sudo apt-get update
sudo apt-get install -y hhvm

sudo /usr/share/hhvm/install_fastcgi.sh
sudo service nginx restart
sudo service hhvm restart


#
#  ========================
#       MariaDB
#  ========================
#

sudo apt-get install -y software-properties-common
sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db
sudo add-apt-repository 'deb http://sfo1.mirrors.digitalocean.com/mariadb/repo/10.0/ubuntu trusty main'
sudo apt-get update
sudo echo mysql-server mysql-server/root_password password $msqlpassroot | debconf-set-selections
sudo echo mysql-server mysql-server/root_password_again password $msqlpassroot | debconf-set-selections
sudo apt-get install -y mariadb-server

#
#  ========================
#       Secure  MariaDB
#  ========================
#

sudo apt-get install -y expect
 
SECURE_MYSQL=$(expect -c "

set timeout 10
spawn mysql_secure_installation

expect \"Enter current password for root (enter for none):\"
send \"$msqlpassroot\r\"

expect \"Change the root password?\"
send \"n\r\"

expect \"Remove anonymous users?\"
send \"y\r\"

expect \"Disallow root login remotely?\"
send \"y\r\"

expect \"Remove test database and access to it?\"
send \"y\r\"

expect \"Reload privilege tables now?\"
send \"y\r\"

expect eof
")
 
echo "$SECURE_MYSQL"
 
sudo apt-get purge -y expect


#
#  ========================
#       Config Nginx
#  ========================
#
#

wordpress_nginx_config=$(curl -L https://raw.githubusercontent.com/wellcome789/UXfresh-shell-script/master/wordpress-nginx.conf)
echo "$wordpress_nginx_config" >> /etc/nginx/sites-available/wordpress
ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default


#
#  ========================
#       Config Redirect
#  ========================
#
#

if [ "$domain" != "" ]; then

# 
# Redirect IP to URL:
# 

sed -i "s/^\# Default server configuration/\# Default server configuration\n\server {\n\tlisten 80;\n\tserver_name $ip_server;\n\treturn 301 \$scheme:\/\/$url\$request_uri;\n\}/" /etc/nginx/sites-available/wordpress

# 
# Redirect Domain to URL:
# 

    if [ "$domain" != "$url" ]; then
        sed -i "s/^\# Default server configuration/\n\server {\n\tlisten 80;\n\tserver_name $domain;\n\treturn 301 \$scheme:\/\/$url\$request_uri;\n\}/" /etc/nginx/sites-available/wordpress
    fi
fi

#
#  ========================
#     Redis Object Cache
#  ========================
#

sudo apt-get install -y redis-server
sudo apt-get install -y php5-redis
sed -i "s/^# maxmemory <bytes>/maxmemory 64mb/" /etc/redis/redis.conf
sudo service redis-server restart


#
#  ========================
#       Restart
#  ========================
#

sudo service nginx restart
sudo service mysql restart
sudo service hhvm restart


#
#  ========================
#       Creat Database
#  ========================
#

mysql -uroot -p$msqlpassroot -e "create database $mysqldb;"
mysql -uroot -p$msqlpassroot -e "create user $mysqluser@localhost;"
mysql -uroot -p$msqlpassroot -e "SET PASSWORD FOR $mysqluser@localhost= PASSWORD('$mysqluserpass');"
mysql -uroot -p$msqlpassroot -e "GRANT ALL PRIVILEGES ON $mysqldb.* TO ${mysqluser}@localhost IDENTIFIED BY '$mysqluserpass';"
mysql -uroot -p$msqlpassroot -e "FLUSH PRIVILEGES;"

#
#  ========================
#       WordPress
#  ========================
#

cd /var/www/html
wget http://wordpress.org/latest.tar.gz && tar -xvzf latest.tar.gz
mv wordpress/* ./ && chown -R www-data:www-data *
sed -e "s/database_name_here/"$mysqldb"/" -e "s/username_here/"$mysqluser"/" -e "s/password_here/"$mysqluserpass"/" wp-config-sample.php > wp-config.php
SALT=$(curl -L https://api.wordpress.org/secret-key/1.1/salt/)
STRING='put your unique phrase here'
printf '%s\n' "g/$STRING/d" a "$SALT" . w | ed -s wp-config.php
rm -rf wordpress latest.tar.gz wp-config-sample.php
chown -R www-data:www-data * && cd


#
#  ========================
#      WordPress Plugin
#  ========================
#
sudo apt-get install -y unzip
cd /var/www/html/wp-content/plugins

    # 1. Purge FastCGI Caching        - Nginx Helper
    wget https://downloads.wordpress.org/plugin/nginx-helper.zip && unzip nginx-helper.zip && rm nginx-helper.zip

    # 2. Conect, Purge Redis Caching  - Redis Object Caching
    wget https://downloads.wordpress.org/plugin/redis-cache.zip && unzip redis-cache.zip && rm redis-cache.zip

    # 3. SEO Plugin                   - WordPress SEO by Yoast
    wget https://downloads.wordpress.org/plugin/wordpress-seo.zip && unzip wordpress-seo.zip && rm wordpress-seo.zip

    # 4. Security WordPress           - iThemes Security
    wget https://downloads.wordpress.org/plugin/better-wp-security.zip && unzip better-wp-security.zip && rm better-wp-security.zip

    # 5. Backup                       - BackWPup
    wget https://downloads.wordpress.org/plugin/backwpup.zip && unzip backwpup.zip && rm backwpup.zip

    # 6. Database Optimization        - WP-Optimize
    wget https://downloads.wordpress.org/plugin/wp-optimize.zip && unzip wp-optimize.zip && rm wp-optimize.zip

    # 7. Image Optimization           - WP Smush
    wget https://downloads.wordpress.org/plugin/wp-smushit.zip && unzip wp-smushit.zip && rm wp-smushit.zip

    # 8. Two-Factor Authentication    - Duo Two-Factor Authentication
    # wget https://downloads.wordpress.org/plugin/duo-wordpress.zip && unzip duo-wordpress.zip && rm duo-wordpress.zip

    # 9. Contact                      - Contact Form 7
    wget https://downloads.wordpress.org/plugin/contact-form-7.zip && unzip contact-form-7.zip && rm contact-form-7.zip

    # 10. Subscribe Mail              - MailChimp for WordPress
    wget https://downloads.wordpress.org/plugin/mailchimp-for-wp.zip && unzip mailchimp-for-wp.zip && rm mailchimp-for-wp.zip

    # 11. Mail SMTP                   - WP Mail SMTP
    wget https://downloads.wordpress.org/plugin/wp-mail-smtp.zip && unzip wp-mail-smtp.zip && rm wp-mail-smtp.zip

    # 12. Google Analytics            - Google Analytics by Yoast
    wget https://downloads.wordpress.org/plugin/google-analytics-for-wordpress.zip && unzip google-analytics-for-wordpress.zip && rm google-analytics-for-wordpress.zip

    # 13. Broken Link Checker         - Broken Link Checker
    wget https://downloads.wordpress.org/plugin/broken-link-checker.zip && unzip broken-link-checker.zip && rm broken-link-checker.zip

    # 14. Social Sharing              - AddThis Sharing Buttons
    wget https://downloads.wordpress.org/plugin/addthis.zip && unzip addthis.zip && rm addthis.zip

chown -R www-data:www-data * && cd


#
#  ========================
#     Remove File Setup
#  ========================
#

rm -rf wpfresh
clear



#
#  ========================
#     Complete
#  ========================
#

echo "**********************************************************************************"
echo "Qua trinh cai dat hoan thanh."
echo "Truy cap vao IP hoac Domain de cai dat Wordpress Site va thuc hien cac buoc tiep theo"
echo "=================================================================================="
echo "Đây là thông tin Database của bạn được tạo tự động (Nhớ sao lưu lại nhé!)"
echo "MariaDB 'root' user password: $msqlpassroot"
echo "Database name': $mysqldb"
echo "Database user': $mysqluser"
echo "Passowrd cho Database user': $mysqluserpass"
echo "=================================================================================="
echo "**********************************************************************************"
