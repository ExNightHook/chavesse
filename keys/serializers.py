from django.db.models import TextChoices
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers as s

from .models import Key


class Status(TextChoices):
    SUCCESS = ('success', 'Ключ зарегистрирован успешно')
    HWID_MISMATCH = ('hwid mismatch', 'Неверный идентификатор устройства')


class KeySerializer(s.ModelSerializer):
    key = s.CharField(source='value', max_length=255, help_text='Ключ')
    uuid = s.UUIDField(
        write_only=True,
        source='device_uuid',
        help_text='UUID устройства',
    )
    status = s.SerializerMethodField(read_only=True, help_text='Статус запроса')

    class Meta:
        model = Key
        fields = ('key', 'uuid', 'status')

    @extend_schema_field(s.ChoiceField(choices=Status.choices))
    def get_status(self, key):
        return self.context['status']
