#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y nginx php5-fpm php5-mysql php5-cli php5-dev php5-gd php5-mcrypt mysql-server nodejs nodejs-legacy git npm
# Install bower and gulp
npm install -g gulp bower
# Enable mcrypt for PHP
php5enmod mcrypt
# Set up nginx config
unlink /etc/nginx/sites-enabled/default
cat > /etc/nginx/sites-available/sandstorm-php <<EOF
server {
    listen 8000 default_server;
    listen [::]:8000 default_server ipv6only=on;

    root /opt/app/frontend/public;
    index index.php index.html index.htm;

    server_name example.com;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_pass unix:/var/run/php5-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF
ln -s /etc/nginx/sites-available/sandstorm-php /etc/nginx/sites-enabled/sandstorm-php
# Stop services outside the sandbox
service nginx stop
service php5-fpm stop
service mysql stop
# patch /etc/php5/fpm/php-fpm.conf to not change uid/gid to www-data
sed --in-place='' \
        --expression='s/^listen.owner = www-data/#listen.owner = www-data/' \
        --expression='s/^listen.group = www-data/#listen.group = www-data/' \
        --expression='s/^user = www-data/#user = www-data/' \
        --expression='s/^group = www-data/#group = www-data/' \
        /etc/php5/fpm/pool.d/www.conf
# patch mysql conf to not change uid
sed --in-place='' \
        --expression='s/^user\t\t= mysql/#user\t\t= mysql/' \
        /etc/mysql/my.cnf
# patch nginx conf to not bother trying to setuid, since we're not root
sed --in-place='' \
        --expression 's/^user www-data/#user www-data/' \
        --expression 's#^pid /run/nginx.pid#pid /var/run/nginx.pid#' \
        /etc/nginx/nginx.conf
# Add a conf snippet providing what sandstorm-http-bridge says the protocol is as var fe_https
cat > /etc/nginx/conf.d/50sandstorm.conf << EOF
    # Trust the sandstorm-http-bridge's X-Forwarded-Proto.
    map \$http_x_forwarded_proto \$fe_https {
        default "";
        https on;
    }
EOF
# Adjust fastcgi_params to use the patched fe_https
sed --in-place='' \
        --expression 's/^fastcgi_param\tHTTPS.*$/fastcgi_param\tHTTPS\t\t\$fe_https if_not_empty;/' \
        /etc/nginx/fastcgi_params
