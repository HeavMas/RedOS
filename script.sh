#!/bin/bash

set -e

# Обновление системы
echo "Обновление системы..."
sudo dnf upgrade --refresh -y

# Установка DHCP-сервера
echo "Установка DHCP-сервера..."
sudo dnf install -y dhcp-server

# Настройка DHCP-сервера
echo "Настройка DHCP-сервера..."
cat <<EOT | sudo tee /etc/dhcp/dhcpd.conf
subnet 10.10.10.0 netmask 255.255.255.0 {
   range 10.10.10.3 10.10.10.100;
   range 10.10.10.150 10.10.10.200;
   option domain-name-servers 77.88.8.88, 77.88.8.2;
   option routers 10.10.10.1;
   option broadcast-address 10.10.10.255;
   default-lease-time 600;
   max-lease-time 7200;
} 
EOT

# Указание интерфейса для DHCP-сервера
echo "Указание интерфейса для DHCP-сервера..."
echo "DHCPDARGS=enp7s0" | sudo tee /etc/sysconfig/dhcpd

# Настройка сетевого интерфейса
echo "Настройка сетевого интерфейса..."
cat <<EOT | sudo tee /etc/sysconfig/network-scripts/ifcfg-enp7s0
TYPE="Ethernet"
BOOTPROTO="none"
DNS1="10.10.10.1"
IPADDR0="10.10.10.1"
PREFIX0=24
GATEWAY0=10.10.10.1
DEFROUTE="yes"
PEERDNS="yes"
PEERROUTES="yes"
IPV4_FAILURE_FATAL="no"
IPV6INIT="yes"
IPV6_AUTOCONF="yes"
IPV6_DEFROUTE="yes"
IPV6_PEERDNS="yes"
IPV6_PEERROUTES="yes"
IPV6_FAILURE_FATAL="no"
IPV6_ADDR_GEN_MODE="stable-privacy"
NAME="enp7s0"
DEVICE="enp7s0"
ONBOOT="yes"
EOT

# Включение и запуск DHCP-сервера
echo "Включение и запуск DHCP-сервера..."
sudo systemctl enable dhcpd
sudo systemctl start dhcpd

# Установка FTP-сервера
echo "Установка FTP-сервера..."
sudo dnf install -y vsftpd ftp nano policycoreutils-python-utils

# Включение и настройка FTP-сервера
echo "Настройка FTP-сервера..."
sudo systemctl enable vsftpd --now
sudo cp /etc/vsftpd/vsftpd.conf /etc/vsftpd/vsftpd.conf.backup

cat <<EOT | sudo tee /etc/vsftpd/vsftpd.conf
anonymous_enable=NO
user_config_dir=/etc/vsftpd_user_conf
pasv_enable=YES
local_enable=YES
write_enable=YES
chroot_local_user=YES
allow_writeable_chroot=YES
EOT

# Создание пользователя FTP
echo "Создание пользователя FTP..."
sudo useradd user1 -d /home/user1
sudo passwd user1
sudo usermod -aG ftp user1
sudo mkdir -p /etc/vsftpd_user_conf

cat <<EOT | sudo tee /etc/vsftpd_user_conf/user1
local_root=/srv/ftp/
EOT

sudo mkdir -p /srv/ftp
sudo chown -R user1:user1 /srv/ftp

# Настройка SELinux для FTP-сервера
echo "Настройка SELinux для FTP-сервера..."
sudo semanage fcontext -a -t public_content_rw_t "/srv/ftp(/.*)?"
sudo semanage fcontext -a -t httpd_sys_content_t "/srv/ftp(/.*)?"
sudo chcon -R -t httpd_sys_rw_content_t /srv/ftp/
sudo chcon -R -t public_content_rw_t /srv/ftp/
sudo setsebool -P tftp_home_dir on
sudo setsebool -P ftpd_full_access on
sudo restorecon -Rv /srv/ftp

# Перезапуск FTP-сервера
echo "Перезапуск FTP-сервера..."
sudo systemctl restart vsftpd

echo "Настройка завершена!"
