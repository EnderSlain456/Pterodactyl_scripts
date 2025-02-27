#!/bin/bash

# Update and upgrade system
sudo apt update && sudo apt upgrade -y

# Install necessary dependencies
sudo apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg

# Add PHP repository
LC_ALL=C.UTF-8 sudo add-apt-repository -y ppa:ondrej/php

# Add Redis repository
curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list

# Add MariaDB repository
curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | sudo bash

# Update apt cache
sudo apt update

# Install necessary packages
sudo apt -y install php8.3 php8.3-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip} mariadb-server nginx tar unzip git redis-server

# Install Composer if not already installed
if ! command -v composer &> /dev/null; then
    curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
fi

# Set up Pterodactyl
mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl
curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz
chmod -R 755 storage/* bootstrap/cache/

# Configure MariaDB character set
config_file="/etc/mysql/mariadb.conf.d/50-server.cnf"
cp "$config_file" "$config_file.bak"
sed -i '/\[mysqld\]/a character-set-server = utf8mb4\ncollation-server = utf8mb4_general_ci' "$config_file"
sudo systemctl restart mariadb

# Check if MariaDB restarted successfully
if systemctl is-active --quiet mariadb; then
    echo "MariaDB has been restarted successfully!"
else
    echo "Failed to restart MariaDB."
fi

# Prompt for Pterodactyl database password
echo "Please enter a password for the Pterodactyl Database user:"
read -s PterodactylPassword

# Create MySQL user and database
mariadb -u root -p <<EOF
CREATE USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$PterodactylPassword';
CREATE DATABASE panel;
GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION;
EOF

# Configure environment and install dependencies
cp .env.example .env
COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader
php artisan key:generate --force
php artisan p:environment:setup
php artisan p:environment:database
php artisan p:environment:mail
php artisan migrate --seed --force
php artisan p:user:make

# Set file permissions
chown -R www-data:www-data /var/www/pterodactyl/*

# Set up cron job
CRON_JOB="* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1"
if ! crontab -l | grep -q "$CRON_JOB"; then
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
fi

# Set up systemd service for queue worker
cat <<EOF > /etc/systemd/system/pteroq.service
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# Enable services
sudo systemctl enable --now redis-server
sudo systemctl enable --now pteroq.service

echo "Cron job and systemd queue worker setup completed!"
