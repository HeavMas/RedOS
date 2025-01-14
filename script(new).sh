#!/bin/bash

# Обновление системы
echo "Обновление системы..."
sudo dnf upgrade --refresh -y

# Переименование подключения
echo "Переименование подключения в enp7s0..."
nmcli con show
nmcli con mod "Проводное подключение 1" con-name enp7s0

# Установка DHCP-сервера
echo "Установка DHCP-сервера..."
sudo dnf install -y dhcp-server

# Конфигурация файла /etc/dhcp/dhcpd.conf
echo "Настройка файла /etc/dhcp/dhcpd.conf..."
sudo bash -c 'cat > /etc/dhcp/dhcpd.conf <<EOF
subnet 10.10.10.0 netmask 255.255.255.0 {
   range 10.10.10.3 10.10.10.100;
   range 10.10.10.150 10.10.10.200;
   option domain-name-servers 77.88.8.88, 77.88.8.2;
   option routers 10.10.10.1;
   option broadcast-address 10.10.10.255;
   default-lease-time 600;
   max-lease-time 7200;
}
EOF'

# Конфигурация файла /etc/sysconfig/dhcpd
echo "Настройка файла /etc/sysconfig/dhcpd..."
sudo bash -c 'echo "DHCPDARGS=enp7s0" > /etc/sysconfig/dhcpd'

# Настройка сетевого интерфейса через nmcli
echo "Настройка сетевого интерфейса enp7s0..."
nmcli con mod enp7s0 ipv4.addresses 10.10.10.1/24 \
    ipv4.gateway <IP внешнего роутера> \
    ipv4.dns <IP внешнего роутера> \
    ipv4.method manual \
    ipv6.method disabled

# Применение изменений сетевого интерфейса
echo "Применение изменений подключения..."
nmcli con up enp7s0

# Включение и запуск службы DHCP
echo "Включение и запуск службы DHCP..."
sudo systemctl enable dhcpd
sudo systemctl start dhcpd

# Проверка наличия пакета policycoreutils-python-utils
echo "Проверка наличия policycoreutils-python-utils..."
sudo dnf provides /usr/sbin/semanage

# Установка FTP-сервера и необходимых пакетов
echo "Установка FTP-сервера и вспомогательных пакетов..."
sudo dnf install -y vsftpd ftp nano policycoreutils-python-utils

# Настройка FTP-сервера
echo "Настройка FTP-сервера..."
sudo systemctl enable vsftpd --now
sudo cp /etc/vsftpd/vsftpd.conf /etc/vsftpd/vsftpd.conf.backup

sudo bash -c 'cat >> /etc/vsftpd/vsftpd.conf <<EOF
anonymous_enable=NO
user_config_dir=/etc/vsftpd_user_conf
pasv_enable=YES
local_enable=YES
write_enable=YES
chroot_local_user=YES
allow_writeable_chroot=YES
EOF'

# Создание пользователя для FTP
echo "Создание FTP-пользователя..."
sudo useradd user1 -d /home/user1
echo "Введите пароль для пользователя user1:"
sudo passwd user1
sudo usermod -aG ftp user1

# Создание пользовательской конфигурации для FTP
echo "Создание пользовательской конфигурации для FTP..."
sudo mkdir /etc/vsftpd_user_conf
sudo bash -c 'echo "local_root=/srv/ftp/" > /etc/vsftpd_user_conf/user1'

# Настройка FTP-директории
echo "Настройка FTP-директории..."
sudo mkdir -p /srv/ftp
sudo chown -R user1:user1 /srv/ftp

# Настройка SELinux
echo "Настройка SELinux для FTP-директории..."
sudo semanage fcontext -a -t public_content_rw_t "/srv/ftp(/.*)?"
sudo semanage fcontext -a -t httpd_sys_content_t "/srv/ftp(/.*)?"
sudo chcon -R -t httpd_sys_rw_content_t /srv/ftp/
sudo chcon -R -t public_content_rw_t /srv/ftp/
sudo setsebool -P tftp_home_dir on
sudo setsebool -P ftpd_full_access on
sudo restorecon -Rv /srv/ftp

# Перезапуск службы FTP
echo "Перезапуск службы FTP..."
sudo systemctl restart vsftpd
