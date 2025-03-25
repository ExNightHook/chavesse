#!/bin/bash

# Проверка запуска от правильного пользователя
if [ "$(whoami)" != "chavesse" ]; then
    echo "Ошибка: Скрипт должен быть запущен от пользователя chavesse"
    exit 1
fi

HOME_DIR="$HOME"

# Создание структуры каталогов
mkdir -p "$HOME_DIR/chavesse"
cd "$HOME_DIR/chavesse" || exit

# Клонирование репозитория с GitHub
git clone https://github.com/ExNightHook/chavesse.git

# Создание виртуальной среды
"$HOME_DIR/pyenv/versions/3.13.2/bin/python" -m venv "$HOME_DIR/chavesse/env"

# Установка зависимостей
source "$HOME_DIR/chavesse/env/bin/activate"
pip install --upgrade pip wheel
cd "$HOME_DIR/chavesse/chavesse" || exit
pip install -r requirements.txt

# Генерация SECRET_KEY
SECRET_KEY=$(openssl rand -base64 30 | tr -dc 'a-zA-Z0-9!@#$%^&*()_+-' | head -c50)

# Создание local.py
cat << EOF > "$HOME_DIR/chavesse/chavesse/main/settings/local.py"
from .common import *

SECRET_KEY = '$SECRET_KEY'
ALLOWED_HOSTS.append('79.137.192.4')
EOF

# Конфигурация uWSGI
mkdir -p "$HOME_DIR/chavesse/etc"
cat << EOF > "$HOME_DIR/chavesse/etc/chavesse.ini"
[uwsgi]
chdir=$HOME_DIR/chavesse/chavesse
module=main.wsgi
home=$HOME_DIR/chavesse/env
socket=127.0.0.1:9000
master=true
processes=5
EOF

# Настройка systemd сервиса
mkdir -p "$HOME_DIR/.config/systemd/user"
cat << EOF > "$HOME_DIR/.config/systemd/user/chavesse.service"
[Unit]
Description=uWSGI app server (chavesse)

[Service]
ExecStart=$HOME_DIR/chavesse/env/bin/uwsgi --ini $HOME_DIR/chavesse/etc/chavesse.ini
RuntimeDirectory=$HOME_DIR/chavesse/chavesse
Restart=always
KillSignal=SIGQUIT
Type=notify
NotifyAccess=all
StandardError=syslog

[Install]
WantedBy=default.target
EOF

# Активация сервиса
systemctl --user daemon-reload
systemctl --user start chavesse
systemctl --user enable chavesse
sudo loginctl enable-linger chavesse

# Настройка окружения
echo 'export XDG_RUNTIME_DIR="/run/user/$(id -u)"' >> "$HOME_DIR/.bashrc"
source "$HOME_DIR/.bashrc"

# Конфигурация Nginx
sudo bash -c "cat << EOF > /etc/nginx/sites-enabled/chavesse.conf
upstream chavesse {
    server 127.0.0.1:9000;
}

server {
    server_name 79.137.192.4;
    client_max_body_size 32M;

    location /static/ {
        alias $HOME_DIR/chavesse/static/;
    }

    location / {
        uwsgi_pass chavesse;
        include uwsgi_params;
    }

    listen 80;
    listen [::]:80;
}
EOF"

# Перезагрузка Nginx
sudo nginx -t && sudo nginx -s reload

# Миграции и сбор статики
cd "$HOME_DIR/chavesse/chavesse" || exit
source "$HOME_DIR/chavesse/env/bin/activate"
./manage.py migrate
./manage.py collectstatic --noinput

echo "Настройка завершена! Сервис доступен по адресу: http://79.137.192.4"