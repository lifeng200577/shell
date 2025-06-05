#!/bin/bash
# 基于 LAMP 架构安装 WordPress 博客平台 (Ubuntu 版本)
# LAMP 架构和数据库由 apt 进行安装，WordPress 源码包从官网获取

logfile=/var/log/wordpress_install.log
touch $logfile

# 关闭防火墙（Ubuntu默认没有启用防火墙）
sudo ufw disable

# 更新软件源
apt update && apt upgrade -y

# 安装 Apache
install_apache() {
    echo "安装 Apache2 服务..."
    apt install -y apache2
    systemctl start apache2
    systemctl enable apache2
    if systemctl is-active apache2 | grep -q active; then
        echo "Apache 安装并启动成功。" >> $logfile
    else
        echo "Apache 启动失败。" >> $logfile
        exit 1
    fi
}

install_apache

# 安装 MariaDB
install_mariadb() {
    echo "安装 MariaDB..."
    apt install -y mariadb-server
    systemctl start mariadb
    systemctl enable mariadb
    if systemctl is-active mariadb | grep -q active; then
        echo "MariaDB 安装并启动成功。" >> $logfile
    else
        echo "MariaDB 启动失败。" >> $logfile
        exit 1
    fi
}

install_mariadb

# 设置数据库密码
ROOT_PASSWORD=$(openssl rand -base64 12)
echo "随机生成的 root 密码为：$ROOT_PASSWORD" >> $logfile

mysql_secure_installation <<EOF
n
y
$ROOT_PASSWORD
$ROOT_PASSWORD
y
y
y
y
EOF

# 创建 WordPress 数据库
mysql -uroot -p$ROOT_PASSWORD -e "CREATE DATABASE wordpress;"

# 安装 PHP
apt install -y php libapache2-mod-php php-mysql php-cli php-curl php-gd php-mbstring php-xml php-xmlrpc php-zip

# 获取 WordPress 并解压
cd /tmp
apt install -y wget unzip
wget https://cn.wordpress.org/wordpress-4.9.26-zh_CN.zip
unzip wordpress-4.9.26-zh_CN.zip
cp -r wordpress/* /var/www/html/

cd /var/www/html
cp wp-config-sample.php wp-config.php

# 配置 wp-config.php
sed -i "s/database_name_here/wordpress/" wp-config.php
sed -i "s/username_here/root/" wp-config.php
sed -i "s/password_here/$ROOT_PASSWORD/" wp-config.php

# 设置权限
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

# 创建虚拟主机配置
cat <<EOF > /etc/apache2/sites-available/wordpress.conf
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html

    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/wordpress_error.log
    CustomLog \${APACHE_LOG_DIR}/wordpress_access.log combined
</VirtualHost>
EOF

# 启用配置与模块
a2ensite wordpress
a2enmod rewrite
systemctl reload apache2

echo "WordPress 安装完成，请通过浏览器访问服务器 IP 进行初始化设置。" >> $logfile
