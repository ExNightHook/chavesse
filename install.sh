#!/bin/bash

# Версия Python
PYTHON_VERSION="3.13.2"

# Проверка запуска от root
if [ "$(whoami)" != "root" ]; then
    echo "Ошибка: Скрипт должен быть запущен с sudo"
    exit 1
fi

# Установка системных зависимостей
apt update
apt install -y nginx python3-dev python3-venv libmysqlclient-dev \
build-essential libssl-dev zlib1g-dev libffi-dev curl git

# Установка pyenv (если не установлен)
if [ ! -d "$HOME/.pyenv" ]; then
    curl -L https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash
    echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
    echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
    echo 'eval "$(pyenv init --path)"' >> ~/.bashrc
    source ~/.bashrc
fi

# Установка Python через pyenv
if ! pyenv versions | grep -q $PYTHON_VERSION; then
    pyenv install $PYTHON_VERSION
    pyenv global $PYTHON_VERSION
fi

HOME_DIR="/root"

# Создание структуры каталогов
mkdir -p "$HOME_DIR/chavesse"
cd "$HOME_DIR/chavesse" || exit

# Клонирование репозитория
git clone https://github.com/ExNightHook/chavesse.git

# Создание виртуальной среды
$HOME_DIR/.pyenv/versions/$PYTHON_VERSION/bin/python -m venv "$HOME_DIR/chavesse/env"

# Установка зависимостей
source "$HOME_DIR/chavesse/env/bin/activate"
pip install --upgrade pip wheel setuptools
cd "$HOME_DIR/chavesse/chavesse"
pip install -r requirements.txt

# Генерация SECRET_KEY
SECRET_KEY=$(openssl rand -base64 30 | tr -dc 'a-zA-Z0-9!@#$%^&*()_+-' | head -c50)

# Настройка БД (ЗАМЕНИТЕ ПАРОЛЬ!)
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

# Настройка systemd
mkdir -p "$HOME_DIR/.config/systemd/user"
cat << EOF > "$HOME_DIR/.config/systemd/user/chavesse.service"
[Unit]
Description=uWSGI app server (chavesse)

[Service]
ExecStart=$HOME_DIR/chavesse/env/bin/uwsgi --ini $HOME_DIR/chavesse/etc/chavesse.ini
WorkingDirectory=$HOME_DIR/chavesse/chavesse
Restart=always
KillSignal=SIGQUIT
Type=notify
NotifyAccess=all
StandardError=syslog

[Install]
WantedBy=default.target
EOF

# Права и активация сервиса
chmod 644 "$HOME_DIR/.config/systemd/user/chavesse.service"
systemctl --user daemon-reload
systemctl --user enable --now chavesse
loginctl enable-linger root

# Настройка Nginx
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

ln -sf /etc/nginx/sites-available/chavesse.conf /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# Миграции и статика
cd "$HOME_DIR/chavesse/chavesse"
source "$HOME_DIR/chavesse/env/bin/activate"
chmod +x manage.py
./manage.py migrate
./manage.py collectstatic --noinput

echo "Настройка завершена! Сервис доступен по адресу: http://79.137.192.4"
