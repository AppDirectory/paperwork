#!/bin/bash

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
# Add latest nodejs sources
curl -sL https://deb.nodesource.com/setup_7.x | bash -
apt-get update
apt-get install -y nginx php5-fpm php5-mysql php5-cli php5-dev php5-gd php5-mcrypt php5-ldap mysql-server nodejs git
# Install bower and gulp
npm install -g gulp bower
# Enable mcrypt for PHP
php5enmod mcrypt
# Stop and disable services
service nginx stop
service php5-fpm stop
service mysql stop
systemctl disable nginx
systemctl disable php5-fpm
systemctl disable mysql
# patch /etc/php5/fpm/pool.d/www.conf to not change uid/gid to www-data
sed --in-place='' \
        --expression='s/^listen.owner = www-data/;listen.owner = www-data/' \
        --expression='s/^listen.group = www-data/;listen.group = www-data/' \
        --expression='s/^user = www-data/;user = www-data/' \
        --expression='s/^group = www-data/;group = www-data/' \
        /etc/php5/fpm/pool.d/www.conf
# patch /etc/php5/fpm/php-fpm.conf to not have a pidfile
sed --in-place='' \
        --expression='s/^pid =/;pid =/' \
        /etc/php5/fpm/php-fpm.conf
# patch /etc/php5/fpm/pool.d/www.conf to no clear environment variables
# so we can pass in SANDSTORM=1 to apps
sed --in-place='' \
        --expression='s/^;clear_env = no/clear_env=no/' \
        /etc/php5/fpm/pool.d/www.conf
# patch /etc/php5/fpm/php.ini to allow backup uploads up to 100MB in Paperwork
sed --in-place='' \
        --expression='s/^post_max_size =.*/post_max_size = 20M/' \
        --expression='s/^upload_max_filesize =.*/upload_max_filesize = 20M/' \
        --expression='s/^max_execution_time =.*/max_execution_time = 300/' \
        --expression='s/^max_input_time =.*/max_input_time = 360/' \
        /etc/php5/fpm/php.ini
# patch mysql conf to not change uid, and to use /var/tmp over /tmp
# see https://github.com/sandstorm-io/vagrant-spk/issues/195
sed --in-place='' \
        --expression='s/^user\t\t= mysql/#user\t\t= mysql/' \
        --expression='s,^tmpdir\t\t= /tmp,tmpdir\t\t= /var/tmp,' \
        --expression='/\[mysqld]/ a\ secure-file-priv = ""\' \
        /etc/mysql/my.cnf
# patch mysql conf to use smaller transaction logs to save disk space
cat <<EOF > /etc/mysql/conf.d/sandstorm.cnf
[mysqld]
# Set the transaction log file to the minimum allowed size to save disk space.
innodb_log_file_size = 1048576
# Set the main data file to grow by 1MB at a time, rather than 8MB at a time.
innodb_autoextend_increment = 1
EOF

# Go to app directory
cd /opt/app/
# Purge git repository just in case it is there
rm -rf /opt/app/paperwork

# Clone git repository for master build
git clone https://github.com/twostairs/paperwork

# Clone other repos & checkout branches for tests
#git clone https://github.com/Liongold/paperwork
#cd /opt/app/paperwork/
#git checkout branch-name

exit 0
