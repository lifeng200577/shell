#!/bin/bash
#function:一键部署nginx
#author:黎风-2024-10-15
#以root身份进行
script_start=`date +%s`             #脚本开始运行的时间
 
 
#-------------------关闭防火墙-----------------
 
 
stop_firewalld ()
{
    systemctl stop firewalld          #关闭防火墙
    systemctl disable firewalld       #防止防火墙开机自启
}
stop_firewalld
 
 
#-----------------安装nginx需要的依赖包-----------
 
 
echo "正在安装依赖包，请稍等...."
install_gcc ()                      
{
    yum -y install  gcc-c++                          #安装nginx依赖包，为后续安装nginx做准备
    yum install -y pcre pcre-devel                
    yum install -y zlib zlib-devel
    yum install -y openssl openssl-devel
}
install_gcc
 
 
#-----------------下载并解压nginx----------------
 
 
install_wget ()
{
    yum install -y wget               #安装wget，来下载nginx安装包               
}
install_wget
 
echo "正在下载安装包，请稍等......"
wget_nginx ()
{
    wget http://nginx.org/download/nginx-1.26.2.tar.gz     #用wget命令来下载nginx安装包（这 
                                                           # 里我用的是1.26.2版本）
     mkdir /usr/local/nginx                              #在/usr/local/目录下创建nginx目录
echo "正在解压安装包，请稍后。。。。。。"
            tar -zxvf nginx-1.26.2.tar.gz -C /usr/local/nginx        #解压nginx安装包
}
wget_nginx
 
 
#---------------配置并安装服务----------------
 
 
configure ()
{
    cd /usr/local/nginx/nginx-1.26.2 && ./configure   #进入nginx-1.26.2目录中，并且进行配置
    make && make install                              #安装服务
    cd /usr/local/nginx/sbin/ ./nginx -t         #进入到nginx目录中的sbin目录里，启动nginx
}
configure
 
 
#--------------设置服务是否开机自启-------------
 
 
read -p "是否部署nginx服务开机自启（yes=1/no=2）：" a          # 
if [ $a -eq 1 ]                                      #如果这个值小于1   
      then                                           #则输出“开始部署服务机开机自启”                
   echo "开始部署服务开机自启...."
       echo "
[Unit]
Description=nginx
After=network.target
[Service]
Type=forking
ExecStart=/usr/local/nginx/sbin/nginx
ExecReload=/usr/local/nginx/sbin/nginx -s reload             #systemctl管理
ExecStop=/usr/local/nginx/sbin/nginx -s quit                 
PrivateTmp=true
[Install]
WantedBy=multi-user.target" > /lib/systemd/system/nginx.service      #创建nginx.server目录 
                                                                     #并将以上文件输入进去
                                                           #之后就可以用systemctl来做管理了 
                                                       
#-----------------启动nginx服务并且设置为开机自启-------------
#---------------------------查看运行状态---------------------
 
  systemctl start nginx 
  systemctl enable nginx               #开启nginx服务并设置nginx开机自启    
  systemctl status nginx               #查看运行状态[看到active (running)则代表成功运行]
 
 
yum install -y net-tools            #安装net-tools方便后续执行脚本
 
 
echo "服务及开机自启部署成功，请输入`ifconfig | grep inet | cut -d " " -f 10 | head -1`测试"
fi                                          #请输入本机的ip地址来测试
 
script_stop=`date +%s`                             #脚本运行结束的时间
 
run_time=$[$script_stop-$script_start]          #结束时间减去开始时间
 
echo "脚本此次运行时长$run_time秒"        #脚本从开始运行到结束所用的时间
