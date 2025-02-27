apt update && apt upgrade -y

apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg

LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list

curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | sudo bash

apt update

apt -y install php8.3 php8.3-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip} mariadb-server nginx tar unzip git redis-server

curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer

mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl

curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz
chmod -R 755 storage/* bootstrap/cache/

config_file ="/etc/mysql/mariadb.conf.d/50-server.cnf"

cp "$config_file" "$config_file.bak"

sed -i '/\[mysqld\]/a character-set-server = utf8mb4\ncollation-server = utf8mb4_general_ci' "$config_file"

sytemctl restart mariadb

if systemctl is-active --quiet mariadb; then
    echo "MariaDB has been restarted Successfully!"
else
    echo "Failed to restart MariaDB."
fi
