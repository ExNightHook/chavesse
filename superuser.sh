#!/bin/bash

# Скрипт для создания суперпользователя Django

# Пути должны совпадать с вашей установкой
PROJECT_DIR="/root/chavesse/chavesse"
VENV_PATH="/root/chavesse/env/bin/activate"

# Данные суперпользователя
USERNAME="exnighthook"
EMAIL="evo.alg@mail.ru"
PASSWORD="HEkrkNxswn4n"

# Активация окружения
cd "$PROJECT_DIR" || exit
source "$VENV_PATH"

# Создание суперпользователя через Django shell
cat << EOF | python manage.py shell
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='$USERNAME').exists():
    User.objects.create_superuser('$USERNAME', '$EMAIL', '$PASSWORD')
    print('Суперпользователь создан!')
else:
    print('Пользователь уже существует!')
EOF

echo "Проверка доступа: http://79.137.192.4/admin/"