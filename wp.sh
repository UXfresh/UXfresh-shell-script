#!/bin/bash
while [ 1 ];do
clear
echo "============================================"
echo " || Create MySQL database"
echo "============================================"
read -p "Enter your MySQL root password: " msqlpassroot
read -p "Enter Database name: " mysqldb
read -p "Enter Database username: " mysqluser
read -p "Enter a password for user $mysqluser: " mysqluserpass
if [ "$msqlpassroot" != "" ] && [ "$mysqldb" != "" ] && [ "$mysqluser" != "" ] && [ "$mysqluser" != "" ]; then
	break
fi
done
while [ 1 ];do
clear
echo "============================================"
echo " || Configuration your Domain [mywebsite.com]"
echo " || Redirect IP [178.62.121.x] to Domain [mywebsite.com]"
echo " || Redirect Domain [mywebsite.com] to URL [www.mywebsite.com]"
echo " || *************************************"
echo " || * | Note: You need to setup the DNS |*"
echo " || *************************************"
echo "============================================"
read -p "Enter your domain [e.g. mywebsite.com]: " servername
read -p "Enter your IP Server [e.g. 178.62.121.x]: " serverIP
read -p "Enter your WordPress URL? [e.g. www.mywebsite.com]: " url
if [ "$servername" != "" ] && [ "$serverIP" != "" ] && [ "$url" != "" ]; then
	break
fi
done

while [ 1 ];do
clear
echo "============================================"
echo " || Configuration Max size memory FastCGI cache [e.g. 1024]"
echo " || *************************************"
echo " || * | Note: Like Max_size = RAM system on VPS |*"
echo " || *************************************"
echo "============================================"
read -p "Enter your Max size memory FastCGI cache [e.g. 1024]: " maxcache
if [ "$maxcache" != "" ]; then
	break
fi
done

clear
echo "============================================"
echo " || Configuration your Email notifications IP banned by Fail2ban"
echo " || **************************************************************"
echo " || * | Note: Leave it empty if you don't want to notifications |*"
echo " || **************************************************************"
echo "============================================"
read -p "Enter your email [e.g. mail@gmail.com]: " MAIL

clear
echo "============================================"
echo " || Two-Factor Authentication for SSH by DuoSecurity.com"
echo " || Create a new UNIX Integration to get an integration key, secret key, and API hostname."
echo " || ********************************************************"
echo " || * | Note: Leave it empty if you don't want to install |*"
echo " || ********************************************************"
echo "============================================"
read -p "Enter your Integrationkey [e.g. DIIDN0V63ZBZE0WESxxx]: " Integrationkey
read -p "Enter your Secretkey [e.g. DBRaVog9rG2pWqk1r9JEMExxx]: " Secretkey
read -p "Enter your APIhostname [e.g. api-8d563xxx.duosecurity.com]: " APIhostname

clear
#Link plugin
plugin="https://www.dropbox.com/s/hxbpgwd16l5s375/plugin.zip"

#Update Ubuntu 14.04
sudo apt-get update

#Install Unzip
sudo apt-get -y install unzip

#Install Nginx
sudo apt-get -y install nginx

#Install MySQL
echo mysql-server mysql-server/root_password password $msqlpassroot | sudo debconf-set-selections
echo mysql-server mysql-server/root_password_again password $msqlpassroot | sudo debconf-set-selections
sudo apt-get -y install mysql-server mysql-client

#Install PHP-FPM & Extentions
sudo apt-get install -y php5-mysql php5-fpm php5-gd php5-cli php5-curl

#Configuration PHP-FPM
sed -i "s/^;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php5/fpm/php.ini
sed -i "s/^;listen.owner = www-data/listen.owner = www-data/" /etc/php5/fpm/pool.d/www.conf
sed -i "s/^;listen.group = www-data/listen.group = www-data/" /etc/php5/fpm/pool.d/www.conf
sed -i "s/^;listen.mode = 0660/listen.mode = 0660/" /etc/php5/fpm/pool.d/www.conf

#File no_cache.conf - FastCGI
wget -O /etc/nginx/no_cache.conf https://raw.githubusercontent.com/UXfresh/UXfresh-shell-script/master/no_cache.conf

#Creat folder seve Cache, Configuration Nginx & FastCGI
mkdir /usr/share/nginx/cache
sed -i "s/^\tworker_connections 768;/\tworker_connections 1536;/" /etc/nginx/nginx.conf
sed -i "s/^\t#passenger_ruby \/usr\/bin\/ruby;/\t#passenger_ruby \/usr\/bin\/ruby;\n\n\tfastcgi_cache_path \/usr\/share\/nginx\/cache\/fcgi levels=1:2 keys_zone=wordpress:10m max_size=${maxcache}m inactive=1h;/" /etc/nginx/nginx.conf
sed -i "s/^\tindex index.html index.htm;/\tindex index.php index.html index.htm;/" /etc/nginx/sites-available/default
sed -i "s/^\tserver_name localhost;/\tserver_name $servername;\n\n\tinclude \/etc\/nginx\/no_cache.conf;/" /etc/nginx/sites-available/default
sed -i "s/^\tlocation \/ {/\n\tlocation ~ \\\.php$ {\n\t\ttry_files \$uri =404;\n\t\tfastcgi_split_path_info ^(.+\\\.php)(\/.+)\$;\n\t\tfastcgi_cache  wordpress;\n\t\tfastcgi_cache_key \$scheme\$host\$request_uri\$request_method;\n\t\tfastcgi_cache_valid 200 301 302 30s;\n\t\tfastcgi_cache_use_stale updating error timeout invalid_header http_500;\n\t\tfastcgi_pass_header Set-Cookie;\n\t\tfastcgi_pass_header Cookie;\n\t\tfastcgi_ignore_headers Cache-Control Expires Set-Cookie;\n\t\tfastcgi_pass unix:\/var\/run\/php5-fpm.sock;\n\t\tfastcgi_index index.php;\n\t\tfastcgi_cache_bypass \$skip_cache;\n\t\tfastcgi_no_cache \$skip_cache;\n\t\tinclude fastcgi_params;\n\t}\n\tlocation \/ {/" /etc/nginx/sites-available/default
sed -i "s/^\t\t# First attempt to serve request as file, then/\t\t# First attempt to serve request as file, then\n\t\ttry_files \$uri \$uri\/ \/index.php?\$args;/" /etc/nginx/sites-available/default
sed -i "s/^\t\ttry_files \$uri \$uri\/ =404;/\t\t#try_files \$uri \$uri\/ =404;/" /etc/nginx/sites-available/default

#Restart Nginx, MySQL, PHP-FPM
service nginx restart
service mysql restart
service php5-fpm restart

#Install Fail2ban
sudo apt-get -y install fail2ban
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
sudo apt-get -y install sendmail iptables-persistent

#Configuration IPtables (Firewall)
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -A INPUT -j DROP

#Configuration Fail2ban
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sed -i "s/^bantime  = 600/bantime  = 3600/" /etc/fail2ban/jail.local
sed -i "s/^findtime = 600/findtime = 300/" /etc/fail2ban/jail.local
if [ "$MAIL" != "" ]; then
    sed -i "s/^\destemail = root@localhost/\destemail = $MAIL/" /etc/fail2ban/jail.local
    sed -i "s/^action = %(action_)s/action = %(action_mwl)s/" /etc/fail2ban/jail.local
fi
sudo service fail2ban stop
sudo service fail2ban start

#Configuration DuoSecurity
if [ "$Integrationkey" != "" ] && [ "$Secretkey" != "" ] && [ "$APIhostname" != "" ]; then
    sudo apt-get -y install libssl-dev libpam-dev
    sudo wget https://dl.duosecurity.com/duo_unix-latest.tar.gz
    tar zxf duo_unix-latest.tar.gz
    rm -rf duo_unix-latest.tar.gz
    cd duo_unix-1.9.14
    ./configure --prefix=/usr && make && sudo make install && cd
    sed -i "s/^ikey = /ikey = $Integrationkey/" /etc/duo/login_duo.conf
    sed -i "s/^skey = /skey = $Secretkey/" /etc/duo/login_duo.conf
    sed -i "s/^host = /host = $APIhostname/" /etc/duo/login_duo.conf
    sed -i "s/^\# See the sshd_config(5) manpage for details/\# See the sshd_config(5) manpage for details\n\ForceCommand \/usr\/sbin\/login_duo\n\PermitTunnel no\n\AllowTcpForwarding no/" /etc/ssh/sshd_config
    service ssh restart
fi

#Create CSDL website
mysql -uroot -p$msqlpassroot -e "create database $mysqldb;"
mysql -uroot -p$msqlpassroot -e "create database $mysqldb;"
mysql -uroot -p$msqlpassroot -e "create user $mysqluser@localhost;"
mysql -uroot -p$msqlpassroot -e "SET PASSWORD FOR $mysqluser@localhost= PASSWORD('$mysqluserpass');"
mysql -uroot -p$msqlpassroot -e "GRANT ALL PRIVILEGES ON $mysqldb.* TO ${mysqluser}@localhost IDENTIFIED BY '$mysqluserpass';"
mysql -uroot -p$msqlpassroot -e "FLUSH PRIVILEGES;"

#Install Wordpress
cd /usr/share/nginx/html
wget http://wordpress.org/latest.tar.gz
tar -xvzf latest.tar.gz
mv wordpress/* ./
wget -O /tmp/wp.keys https://api.wordpress.org/secret-key/1.1/salt/
chown -R www-data:www-data *
sed -e "s/database_name_here/"$mysqldb"/" -e "s/username_here/"$mysqluser"/" -e "s/password_here/"$mysqluserpass"/" wp-config-sample.php > wp-config.php
sed -i '/#@-/r /tmp/wp.keys' wp-config.php
sed -i "/#@+/,/#@-/d" wp-config.php
rm -rf wordpress
rm -rf latest.tar.gz
rm -rf /tmp/wp.keys
chown -R www-data:www-data *
#Install Plugin
cd /usr/share/nginx/html/wp-content/plugins
wget $plugin
unzip plugin.zip
rm -rf plugin.zip
chown -R www-data:www-data *
cd

#Change max upload to 50MB
sed -i "s/^\ttypes_hash_max_size 2048;/\ttypes_hash_max_size 2048;\n\tclient_max_body_size 50M;/" /etc/nginx/nginx.conf
sed -i "s/^upload_max_filesize = 2M/upload_max_filesize = 50M/" /etc/php5/fpm/php.ini

#Restart Nginx, MySQL, PHP-FPM
service nginx restart
service mysql restart
service php5-fpm restart

#Nginx Rewrite redirect IP to Domain
if [ "$servername" != "$url" ]; then
    sed -i "s/^\# statements for each of your virtual hosts to this file/\# statements for each of your virtual hosts to this file\n\server {\n\tlisten 80;\n\tserver_name $servername;\n\treturn 301 \$scheme:\/\/$url\$request_uri;\n\}/" /etc/nginx/sites-available/default
fi

sed -i "s/^\# statements for each of your virtual hosts to this file/\# statements for each of your virtual hosts to this file\n\server {\n\tlisten 80;\n\tserver_name $serverIP;\n\treturn 301 \$scheme:\/\/$url\$request_uri;\n\}/" /etc/nginx/sites-available/default
service nginx restart

#Remove file
rm -rf wp.sh
clear
echo "Successful!"
echo "Access $serverIP or $servername or $url to install your website"
