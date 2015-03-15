# Use phusion/baseimage as base image. To make your builds reproducible, make
# sure you lock down to a specific version, not to `latest`!
# See https://github.com/phusion/baseimage-docker/blob/master/Changelog.md for
# a list of version numbers.
FROM phusion/baseimage:0.9.16

# Set correct environment variables.
ENV HOME /root

# Disable SSH
RUN rm -rf /etc/service/sshd /etc/my_init.d/00_regen_ssh_host_keys.sh

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

# Update Apt
RUN apt-get update

# Install Mysql
RUN apt-get -y install mysql-server

# Install php
RUN apt-get -y install php5 php5-fpm php5-cli php5-mcrypt php5-mysql php5-gd
RUN php5enmod mcrypt

# Install nginx
RUN apt-get -y install nginx

# minimize mysql allocations
RUN echo '[mysqld]\ninnodb_data_file_path = ibdata1:10M:autoextend\ninnodb_log_file_size = 10KB\ninnodb_file_per_table = 1' > /etc/mysql/conf.d/small.cnf
RUN sed -i 's_^socket\s*=.*_socket = /tmp/mysqld.sock_g' /etc/mysql/*.cnf && ln -s /tmp/mysqld.sock /var/run/mysqld/mysqld.sock
RUN rm -rf /var/lib/mysql/* && mysql_install_db && chown -R mysql: /var/lib/mysql

# Setup mysql//mysql user
RUN /usr/sbin/mysqld & \
sleep 10s &&\
echo "DROP DATABASE IF EXISTS paperwork; CREATE DATABASE IF NOT EXISTS paperwork DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci; GRANT ALL PRIVILEGES ON paperwork.* TO 'paperwork'@'localhost' IDENTIFIED BY 'paperwork' WITH GRANT OPTION; FLUSH PRIVILEGES;" | mysql

# setup nginx
ADD nginx.conf /etc/nginx/nginx.conf
RUN echo "cgi.fix_pathinfo = 0;" >> /etc/php5/fpm/php.ini
RUN sed -i 's_^listen\s*=\s*.*_listen = 127.0.0.1:9000_g' /etc/php5/fpm/pool.d/www.conf
RUN sed -i 's_^user\s*=\s*.*_user = 1000_g' /etc/php5/fpm/pool.d/www.conf
RUN sed -i 's_^group\s*=\s*.*_group = 1000_g' /etc/php5/fpm/pool.d/www.conf

RUN mkdir /etc/service/mysql
ADD mysql.sh /etc/service/mysql/run

RUN mkdir /etc/service/php
ADD php.sh /etc/service/php/run

RUN mkdir /etc/service/nginx
ADD nginx.sh /etc/service/nginx/run

ADD . /opt/app
RUN rm -rf /opt/app/.git
RUN chmod -R 777 /opt/app

# move storage folders which must be writable to /var
# move default content
RUN mv /opt/app/frontend/app/storage  /var/storage
# chmod the folder
RUN chmod -R 777 /var/storage
# symlink folders to /var
RUN ln -s /var/storage /opt/app/frontend/app/storage

EXPOSE 33411

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN rm -rf /usr/share/vim /usr/share/doc /usr/share/man /var/lib/dpkg /var/lib/belocs /var/lib/ucf /var/cache/debconf /var/log/*.log

# Run init script from paperwork
# Needs to be run at first start of docker container
# RUN cd /opt/app/frontend && php artisan migrate --force
