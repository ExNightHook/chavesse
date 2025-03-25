# Chavesse

Простой сервис для управления ключами.

## pyenv

В репозиториях массовых дистрибутивов Linux обычно поставляются старые как говно
мамонта версии Python. Для использования любых версий Python установите
[pyenv](https://github.com/pyenv/pyenv) по
[инструкции](https://github.com/pyenv/pyenv?tab=readme-ov-file#installation).
Обратите особое внимание на необходимость создать
[среду для сборки Python](https://github.com/pyenv/pyenv/wiki#suggested-build-environment).

Команда для сборки необходимой версии Python (например, 3.13.2):

```bash
pyenv install 3.13.2
```

Собранный интерпретатор будет находиться в папке `~/.pyenv/versions/3.13.2`.

## База данных

Инструкция для Mysql, но сервис может работать на любой СУБД, которую
поддерживает Django.

Запустите консоль mysql:

```bash
sudo mysql
```

или

```bash
sudo -u mysql mysql
```

Создайте пользователя с паролем и базу данных:

```mysql
CREATE USER 'chavesse'@localhost IDENTIFIED BY '********';
CREATE DATABASE chavesse;
GRANT ALL PRIVILEGES ON chavesse.* TO 'chavesse'@localhost;
```

Подставьте свой пароль вместо `********`.

Выход из консоли mysql: `^D`.

## Структура каталогов

Для безопасной работы сервис должен запускаться от простого пользователя
(не **root**).

Войдите на целевой компьютер (VPS, контейнер) как простой пользователь. Создайте
каталог для инсталляции сервиса в домашней папке:

```bash
mkdir ~/chavesse
cd chavesse
```

Сюда мы доставим код. Из этой папки будем запускать все дальнейшие команды,
если явно не сказано иное.

## Доставка (кода) сервиса

Загрузите папку с кодом сервиса в свой домашний каталог. Лучше это сделать при
помощи `git`, предварительно настроив доступ по `ssh` и создав и загрузив на
целевой компьютер и на хостинг кода (**gitlab**) необходимые
[сертификаты](https://docs.gitlab.com/user/ssh/).

```bash
git clone git@gitlab.com:jock_tanner/chavesse.git
```

Альтернативно можно скачать с **gitlab** папку с кодом репозитория, а потом
развернуть её на целевом компьютере, но это менее безопасное и в перспективе
более трудоёмкое решение.

## Виртуальная среда

Создайте виртуальную среду и активируйте её:

```bash
~/pyenv/versions/3.13.2/bin/python -m venv env
source env/bin/activate
```

Установите зависимости:

```bash
pip install --upgrade pip wheel
cd chavesse
pip install -r requirements.txt
```

## Конфигурация сервиса

### Локальные настройки Django

Сгенерируйте строку из 50 символов. Допустимы латинские буквы в любом регистре,
цифры, пунктуация. Это строка будет использоваться Django как секретный ключ
при криптографических операциях, например, для засолки хешей паролей.

Создайте файл `~/chavesse/chavesse/main/settings/local.py`.

Отредактируйте его содержимое по образцу:

```python
from .common import *  # обязательно должно быть в начале

SECRET_KEY = '****'  # вместо звёздочек подставьте секретный ключ из 50 символов

ALLOWED_HOSTS.append('example.com')  # в кавычках задайте доменное имя вместо “example.com”
```

### Конфигурация uWSGI

Создайте файл `~/chavesse/etc/chavesse.ini` по образцу:

```ini
[uwsgi]
chdir=/home/user/chavesse/chavesse
module=main.wsgi
home=/home/user/chavesse/env
socket=127.0.0.1:9000
master=true
processes=5
```

Вместо `/home/user` подставьте расположение каталога вашего пользователя на
целевом компьютере. Символ `~` здесь не сработает. Также вы можете выбрать любой
другой сокет (от 1000 до 65535), если 9000 занят.

### Сервис systemd

Создайте файл **systemd**-сервиса `~/.config/systemd/user/chavesse.service` по
следующему образцу:

```ini
[Unit]
Description=uWSGI app server (example.com)

[Service]
ExecStart=/home/user/chavesse/env/bin/uwsgi --ini /home/user/chavesse/etc/chavesse.ini
RuntimeDirectory=/home/user/chavesse/chavesse
Restart=always
KillSignal=SIGQUIT
Type=notify
NotifyAccess=all
StandardError=syslog

[Install]
WantedBy=default.target
```

Вместо `/home/user` подставьте расположение каталога вашего пользователя на
целевом компьютере.

Теперь запустите сервис и настройте его автоматический запуск.

```bash
systemctl --user daemon-reload
systemctl --user start chavesse
systemctl --user enable chavesse
```

Проверить работу сервиса можно следующей командой:

```bash
systemctl --user status chavesse
```

Чтобы **systemd** запускал сервис при загрузке компьютера, без необходимости
входить в аккаунт пользователя, от имени которого запускается сервис, запустите
следующую команду:

```bash
sudo loginctl enable-linger user
```

Вместо `user` подставьте реальное имя пользователя.

Также надо сказать, что `systemctl` использует D-bus для связи с демоном
**systemd**, поэтому бывает не лишне настроить работу D-bus в пользовательском
режиме. На Debian и Ubuntu это делает пакет **dbus-user-session**, в других
дистрибутивах может быть необходимо добавить в файл настройки пользовательской
оболочки (`.bashrc` или `.profile` для `bash`) следующую строку:

```bash
export XDG_RUNTIME_DIR=/run/user/$(id -u)
```

### Сайт nginx

Создайте файл `/etc/nginx/sites-enable/chavesse.conf` по следующему образцу:

```nginx
upstream chavesse {
    server 127.0.0.1:9000;
}

server {
    server_name example.com;
    client_max_body_size 32M;

    location /static/ {
        alias /home/user/chavesse/static/;
    }

    location / {
        uwsgi_pass chavesse;
        include uwsgi_params;
    }

    listen 80;
}
```

Вместо `/home/user` подставьте расположение каталога вашего пользователя на
целевом компьютере, вместо `example.com` – реальное доменное имя, а вместо
`9000` – номер порта, выбранный вами в настройках **uWSGI**.

Перезапустите **nginx**:

```bash
sudo nginx -s reload
```

## Подготовка к запуску сервиса

Пока виртуальная среда активна, запустите следующие команды:

```bash
./manage.py migrate
./manage.py collectstatic
```

Ещё можно сразу создать пользователя-администратора:

```bash
./manage.py createsuperuser
```

## Как обновить версию

Обновите исходный код:

```bash
cd ~/chavesse/chavesse
git pull
```

Активируйте виртуальную среду:

```bash
source ../env/bin/activate
```

Если изменилась структура базы данных, то примените миграции:

```bash
./manage.py migrate
```

Если добавились изменения на фронтенде, то соберите ассеты:

```bash
./manage.py collectstatic
```

Перезапустите **systemd**-сервис:

```bash
systemctl --user restart chavesse
```
