#!/bin/bash
#基于LAMP架构安装wordpress博客平台
#LAMP架构和数据库由yum进行安装
#wordpress源码包在官方网站进行拉取

logfile=/var/log/wordpress_install.log
touch $logfile
#基础准备工作
systemctl stop firewalld
setenforce 0

echo "正在配置阿里源..."
curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
yum clean all && yum repolist
echo "阿里源更新完成" >> $logfile

# 安装 httpd 服务
install_httpd_service() {
    echo "开始安装 httpd 服务..."
    yum -y install httpd
    if [ $? -ne 0 ]; then
        echo "安装 httpd 服务失败。错误信息：$(yum -y install httpd 2>&1)" >> $logfile
        exit 1
    fi
    echo "httpd 服务安装成功。" >> $logfile
}

install_httpd_service

# 启动 httpd 服务并设置开机自启
start_and_enable_httpd() {
    echo "启动 httpd 服务并设置开机自启..."
    systemctl start httpd
    systemctl enable httpd
    yum -y install net-tools
    if netstat -lnpt | grep 80; then
        echo "httpd 服务启动成功" >> $logfile
    else
        echo "httpd 服务启动失败"
        systemctl status httpd >> $logfile
        exit 1
    fi
}

start_and_enable_httpd

# 下载 MariaDB 数据库
install_mariadb() {
    echo "开始安装 MariaDB 数据库..."
    yum -y install mariadb mariadb-server mariadb-libs
    if [ $? -ne 0 ]; then
        echo "安装 MariaDB 数据库失败。错误信息：$(yum -y install mariadb mariadb-server mariadb-libs 2>&1)" >> $logfile
        exit 1
    fi
    echo "MariaDB 数据库安装成功。" >> $logfile
}

install_mariadb

systemctl start mariadb && systemctl enable mariadb
#检查
if netstat -lnpt | grep 3306;then
    echo "数据库启动成功" >> $logfile
else
    echo "数据库启动失败"
    systemctl status mariadb >> $logfile
    exit 1
fi

# 生成安全的随机密码
ROOT_PASSWORD=$(openssl rand -base64 12)
echo "随机生成的root密码为：$ROOT_PASSWORD" >> $logfile

DB_NAME="wordpress"

sed -i '/\[mysqld\]/a skip-grant-tables' /etc/my.cnf
# 登录到MySQL
mysql -e "update mysql.user set authentication_string=password('$ROOT_PASSWORD') where user='root' ;"
if [ $? -ne 0 ]; then
    echo "登录到 MySQL 并设置密码失败。错误信息：$(mysql -e "update mysql.user set authentication_string=password('$ROOT_PASSWORD') where user='root' ;" 2>&1)" >> $logfile
    exit 1
fi

systemctl restart mariadb
if ! systemctl restart mariadb; then
    echo "重启数据库服务失败,错误信息：$(systemctl status mariadb 2>&1)" >> $logfile
    exit 1
fi

# 创建WordPress数据库
mysql -u root -p$ROOT_PASSWORD -e "CREATE DATABASE $DB_NAME;"

php=(php php-mysql php-odbc php-pear php-xml php-xmlrpc)
#下载php
yum -y install "${php[@]}"
#检查
for package in "${php[@]}"; do
    rpm -q $package >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "$package 安装失败，错误信息：$(yum -y install $package 2>&1)" >> $logfile
        exit 1
    else
        echo "$package 安装成功。" >> $logfile
    fi
done

#获取wordpress源码包
#检查wget是否存在
yum -y install wget
wget https://cn.wordpress.org/wordpress-4.9.26-zh_CN.zip

if [ -f wordpress-4.9.26-zh_CN.zip ] && [ -s wordpress-4.9.26-zh_CN.zip ]; then
    echo "wordpress下载成功。" >> $logfile
else
    echo "wordpress下载失败,请检查是否是网络连接问题" >> $logfile
    exit 1
fi

yum -y install unzip

unzip wordpress-4.9.26-zh_CN.zip
if [ ! -d "wordpress" ];then
    echo "wordpress解压失败，错误信息：$(unzip wordpress-4.9.26-zh_CN.zip 2>&1)" >> $logfile
    exit 1
fi

cp -r wordpress/* /var/www/html/

if [ -f /var/www/html/index.php ];then
    echo "复制 wordpress 文件到 /var/www/html/ 成功" >> $logfile
else
    echo "复制 wordpress 文件到 /var/www/html/ 失败,错误信息：$(cp -r wordpress/* /var/www/html/ 2>&1)" >> $logfile
    exit 1
fi

cd /var/www/html/

#将配置文件模版复制过来:
cp wp-config-sample.php wp-config.php
if [ ! -f "wp-config.php" ];then
    echo "文件复制失败" >> $logfile
    exit 1
fi

#编写配置文件文件
# 定义一个函数来执行 sed 操作并检查结果
perform_sed() {
    local sed_cmd="$1"
    local file="$2"
    sed -i "$sed_cmd" "$file"
    if [ $? -ne 0 ]; then
        echo "在 $file 中执行 '$sed_cmd' 失败。" >> $logfile
        exit 1
    fi
}

# 替换数据库名称
perform_sed "s/define('DB_NAME', 'database_name_here')/define('DB_NAME', 'wordpress')/" wp-config.php
# 替换数据库用户
perform_sed "s/define('DB_USER', 'username_here')/define('DB_USER', 'root')/" wp-config.php
# 替换数据库密码
perform_sed "s/define('DB_PASSWORD', 'password_here')/define('DB_PASSWORD', '$ROOT_PASSWORD')/" wp-config.php
# 替换数据库主机
perform_sed "s/define('DB_HOST', 'localhost')/define('DB_HOST', 'localhost')/" wp-config.php

systemctl restart httpd
if [ $? -ne 0 ]; then 
   echo "重启失败，请检查httpd是否存在问题" >> $logfile
   exit 1
fi

# 创建WordPress虚拟主机配置文件
echo "创建WordPress虚拟主机配置文件"
cat <<EOF > /etc/httpd/conf.d/wordpress.conf
<VirtualHost *:80>
    ServerAdmin webmaster@example.com
    DocumentRoot /var/www/html
    ServerName your_domain.com
    ServerAlias www.your_domain.com

    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog /var/log/httpd/wordpress_error.log
    CustomLog /var/log/httpd/wordpress_access.log combined
</VirtualHost>
EOF

systemctl restart httpd
if [ $? -ne 0 ]; then 
    echo "重启httpd服务失败，请检查虚拟主机配置是否存在问题" >> $logfile
    exit 1
fi

echo "wordpress搭建完成" >> $logfile
echo "wordpress搭建完成，请到浏览器中初始化设置"
#至此，wordpress安装完成。
