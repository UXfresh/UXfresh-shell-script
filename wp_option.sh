#!/bin/bash

# Varibale Config
# 


# newrelic_license_key=68b3a0913323b10776f4536cf4d5f7d3f57cd4dd

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
#      NewRelic
#  ========================
#
#

newrelic_license_key=$3


#
#  ========================
#      Duo for SSH
#  ========================
#
#

Integration_key=$4
Secret_key=$5
API_hostname=$6


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

if [ "$domain" != 1 ]; then

# 
# Redirect IP to URL:
# 

sed -i "s/^\# Default server configuration/\# Default server configuration\n\server {\n\tlisten 80;\n\tserver_name $ip_server;\n\treturn 301 \$scheme:\/\/$url\$request_uri;\n\}/" /etc/nginx/sites-available/wordpress

# 
# Redirect Domain to URL:
# 

    if [ "$domain" != "$url" ]; then
        sed -i "s/^\# Default server configuration/\# Default server configuration\n\server {\n\tlisten 80;\n\tserver_name $domain;\n\treturn 301 \$scheme:\/\/$url\$request_uri;\n\}/" /etc/nginx/sites-available/wordpress
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
# ======Opition============
#
#


if [ "$newrelic_license_key" != 2 ]; then
    #
    #  ========================
    #   New Relic Monitor Server
    #  ========================
    #

    echo deb http://apt.newrelic.com/debian/ newrelic non-free >> /etc/apt/sources.list.d/newrelic.list
    wget -O- https://download.newrelic.com/548C16BF.gpg | apt-key add -
    apt-get update
    apt-get install -y newrelic-sysmond
    nrsysmond-config --set license_key=$newrelic_license_key
    /etc/init.d/newrelic-sysmond start


    #
    #  ========================
    #   New Relic Nginx Status
    #  ========================
    #

    wget http://nginx.org/keys/nginx_signing.key
    apt-key add nginx_signing.key

    sudo add-apt-repository "deb http://nginx.org/packages/ubuntu/ trusty nginx"
    sudo add-apt-repository "deb-src http://nginx.org/packages/debian/ trusty nginx"
    apt-get update
    apt-get install -y nginx-nr-agent

    sed -i "s/^newrelic_license_key=YOUR_LICENSE_KEY_HERE/newrelic_license_key=$newrelic_license_key/" /etc/nginx-nr-agent/nginx-nr-agent.ini
    sed -i "s/^#name=exampleorg/name=$url/" /etc/nginx-nr-agent/nginx-nr-agent.ini
    sed -i "s/^#url=http:\/\/example.org\/status/url=http:\/\/$url\/status/" /etc/nginx-nr-agent/nginx-nr-agent.ini
    sed -i "s/^\t# Nginx status/\t# Nginx status\n\tlocation = \/status {\n\t\tstub_status on;\n\t\tallow 127.0.0.1;\n\t\tdeny all;\n\t}/" /etc/nginx/sites-available/wordpress

    sudo service nginx restart
    service nginx-nr-agent start

fi

#
#  ========================
#   DuoSecurity
#  ========================
#
#

if [ "$Integration_key" != 3 ] && [ "$Secret_key" != 3 ] && [ "$API_hostname" != 3 ]; then
    # Cài đặt OpenSSL
    apt-get -y install libssl-dev libpam-dev
    
    # Tải và cài đặt Duo Unix 
    wget https://dl.duosecurity.com/duo_unix-latest.tar.gz
    tar zxf duo_unix-latest.tar.gz
    rm -rf duo_unix-latest.tar.gz
    cd duo_unix-1.9.14
    apt-get install -y make
    ./configure --prefix=/usr && make && sudo make install && cd
    
    # Cấu hình login_duo.conf
    sed -i "s/^ikey = /ikey = $Integration_key/" /etc/duo/login_duo.conf
    sed -i "s/^skey = /skey = $Secret_key/" /etc/duo/login_duo.conf
    sed -i "s/^host = /host = $API_hostname/" /etc/duo/login_duo.conf
    sed -i "s/^\# See the sshd_config(5) manpage for details/\# See the sshd_config(5) manpage for details\n\ForceCommand \/usr\/sbin\/login_duo\n\PermitTunnel no\n\AllowTcpForwarding no/" /etc/ssh/sshd_config
    
    # Khởi động lại SSH
    service ssh restart
fi


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

echo "******************************************************************************************"
echo "Qua trinh cai dat hoan thanh"
echo "Truy cap vao IP hoac Domain de cai dat Wordpress Site va thuc hien cac buoc tiep theo"
echo "Đây là thông tin Database của bạn (Nhớ sao lưu lại nhé!)"
echo "MariaDB 'root' user password: $msqlpassroot"
echo "Database name': $mysqldb"
echo "Database user': $mysqluser"
echo "Pasowrd cho Database user': $mysqluserpass"
echo "=========================================================================================="
echo "******************************************************************************************"
