from datetime import timedelta

from django.db.models import Q
from django.utils import timezone
from rest_framework import status
from rest_framework.generics import GenericAPIView, get_object_or_404
from rest_framework.response import Response
from rest_framework.settings import api_settings
from rest_framework.throttling import AnonRateThrottle

from .models import Key
from .serializers import KeySerializer, Status


class KeyRegisterThrottle(AnonRateThrottle):
    rate = '5/min'


class KeyRegisterView(GenericAPIView):
    """
    Активация ключа.
    """
    queryset = Key.objects.all()
    serializer_class = KeySerializer
    throttle_classes = [KeyRegisterThrottle]

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        qs = self.filter_queryset(self.get_queryset())
        key = get_object_or_404(
            qs,
            Q(expired_at__isnull=True) | Q(expired_at__gte=timezone.now()),
            value=serializer.initial_data['key'],
        )
        result = Status.SUCCESS
        if key.is_registered():
            if str(key.device_uuid) != serializer.initial_data['uuid']:
                result = Status.HWID_MISMATCH
        else:
            key.device_uuid = serializer.initial_data['uuid']
            key.expired_at = timezone.now() + timedelta(days=key.duration)
            key.save()
        serializer = self.get_serializer(key, context={'status': result})
        headers = self.get_success_headers(serializer.data)
        return Response(
            serializer.data,
            status=status.HTTP_200_OK,
            headers=headers,
        )

    @staticmethod
    def get_success_headers(data):
        try:
            return {'Location': str(data[api_settings.URL_FIELD_NAME])}
        except (TypeError, KeyError):
            return {}
