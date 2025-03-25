from django.db import models


class Key(models.Model):
    value = models.CharField('Ключ', max_length=255, unique=True)
    created_at = models.DateTimeField('Дата создания', auto_now_add=True)
    expired_at = models.DateTimeField(
        'Дата окончания действия',
        blank=True,
        null=True,
    )
    duration = models.PositiveIntegerField('Период действия (дней)')
    device_uuid = models.UUIDField(
        'Идентификатор устройства',
        blank=True,
        null=True,
    )

    class Meta:
        verbose_name = 'ключ'
        verbose_name_plural = 'ключи'

    def __str__(self):
        return self.value

    def is_registered(self):
        return self.expired_at and self.device_uuid
