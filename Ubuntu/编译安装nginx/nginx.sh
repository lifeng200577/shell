#!/bin/bash
# function: 一键部署 Nginx（Ubuntu 版）
# author: 黎风 - 2024-10-15
# 以 root 身份运行

script_start=$(date +%s)  # 脚本开始运行的时间

# -------------------关闭防火墙-----------------
stop_firewalld () {
    echo "关闭防火墙 ufw（如存在）..."
    systemctl stop ufw 2>/dev/null
    systemctl disable ufw 2>/dev/null
}
stop_firewalld

# -------------------安装依赖包-----------------
echo "正在安装依赖包，请稍等...."
install_dependencies () {
    apt update -y
    apt install -y build-essential libpcre3 libpcre3-dev zlib1g zlib1g-dev libssl-dev wget net-tools
}
install_dependencies

# -------------------下载并解压 nginx 安装包-----------------
wget_nginx () {
    echo "正在下载安装包，请稍等......"
    wget http://nginx.org/download/nginx-1.26.2.tar.gz
    mkdir -p /usr/local/nginx
    echo "正在解压安装包，请稍后........"
    tar -zxvf nginx-1.26.2.tar.gz -C /usr/local/nginx
}
wget_nginx

# -------------------配置并安装 nginx-----------------
configure_nginx () {
    cd /usr/local/nginx/nginx-1.26.2 || exit 1
    ./configure
    make && make install
    /usr/local/nginx/sbin/nginx -t
}
configure_nginx

# -------------------部署 systemd 服务-----------------
read -p "是否部署 nginx 开机自启服务（yes=1 / no=2）： " a
if [ "$a" -eq 1 ]; then
    echo "开始部署服务开机自启...."
    cat > /etc/systemd/system/nginx.service <<EOF
[Unit]
Description=nginx
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/nginx/sbin/nginx
ExecReload=/usr/local/nginx/sbin/nginx -s reload
ExecStop=/usr/local/nginx/sbin/nginx -s quit
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reexec
    systemctl daemon-reload
    systemctl start nginx
    systemctl enable nginx
    systemctl status nginx

    echo "服务及开机自启部署成功，请输入 \`hostname -I | awk '{print $1}'\` 来测试是否能访问"
fi

# -------------------脚本结束-----------------
script_stop=$(date +%s)
run_time=$((script_stop - script_start))
echo "脚本此次运行时长 ${run_time} 秒"

