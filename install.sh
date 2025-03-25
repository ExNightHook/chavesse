#!/bin/bash

# Проверка запуска от правильного пользователя
if [ "$(whoami)" != "root" ]; then
    echo "Ошибка: Скрипт должен быть запущен от пользователя root"
    exit 1
fi

HOME_DIR="/root"

# Создание структуры каталогов
mkdir -p "$HOME_DIR/chavesse"
cd "$HOME_DIR/chavesse" || exit

# Клонирование репозитория
git clone https://github.com/ExNightHook/chavesse.git

# Проверка установки Python
PYTHON_PATH="$HOME_DIR/.pyenv/versions/3.13.2/bin/python"
if [ ! -f "$PYTHON_PATH" ]; then
    echo "Ошибка: Python 3.13.2 не установлен через pyenv!"
    echo "Выполните:"
    echo "1. pyenv install 3.13.2"
    echo "2. pyenv global 3.13.2"
    exit 1
fi

# Создание виртуальной среды (ИСПРАВЛЕН ПУТЬ)
"$PYTHON_PATH" -m venv "$HOME_DIR/chavesse/env"

# Установка зависимостей (ДОБАВЛЕНА ПРОВЕРКА АКТИВАЦИИ)
if [ -f "$HOME_DIR/chavesse/env/bin/activate" ]; then
    source "$HOME_DIR/chavesse/env/bin/activate"
    pip install --upgrade pip wheel
    cd "$HOME_DIR/chavesse/chavesse" || exit
    pip install -r requirements.txt
else
    echo "Ошибка: Не удалось активировать виртуальную среду!"
    exit 1
fi

# Генерация SECRET_KEY
SECRET_KEY=$(openssl rand -base64 30 | tr -dc 'a-zA-Z0-9!@#$%^&*()_+-' | head -c50)

# Создание local.py
cat << EOF > "$HOME_DIR/chavesse/chavesse/main/settings/local.py"
from .common import *

SECRET_KEY = '$SECRET_KEY'
ALLOWED_HOSTS.append('79.137.192.4')

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': 'chavesse',
        'USER': 'chavesse',
        'PASSWORD': 'HEkrkNxswn4n',
        'HOST': 'localhost',
        'PORT': '3306',
    }
}
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

# Права на systemd сервис
chmod 644 "$HOME_DIR/.config/systemd/user/chavesse.service"

# Активация сервиса
systemctl --user daemon-reload
systemctl --user start chavesse
systemctl --user enable chavesse
loginctl enable-linger root

# Настройка окружения
echo 'export XDG_RUNTIME_DIR="/run/user/$(id -u)"' >> "$HOME_DIR/.bashrc"
source "$HOME_DIR/.bashrc"

# Конфигурация Nginx
cat << EOF > /etc/nginx/sites-available/chavesse.conf
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
EOF

# Активация конфига Nginx
ln -sf /etc/nginx/sites-available/chavesse.conf /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# Миграции и сбор статики (ИСПРАВЛЕНЫ ПРАВА)
cd "$HOME_DIR/chavesse/chavesse" || exit
source "$HOME_DIR/chavesse/env/bin/activate"
chmod +x manage.py
./manage.py migrate
./manage.py collectstatic --noinput

echo "Настройка завершена! Сервис доступен по адресу: http://79.137.192.4"
